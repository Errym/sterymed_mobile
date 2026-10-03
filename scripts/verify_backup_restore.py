#!/usr/bin/env python3
"""
T9.5 — backup and restore, actually performed and timed (Cahier §10.5).

On the dev stack (the same commands run on staging with the compose project
there; see docs/BACKUP_RESTORE.md):

  DATABASE   backup:run --only-db  ->  newest dump read back from the `backups`
             bucket  ->  restored into a scratch database  ->  row counts of the
             business tables compared with the live database.
  MEDIA      steriqore:backup-media  ->  a real uploaded photo is deleted from
             the `media` disk (its link answers 404)  ->  RestoreMediaBackupAction
             ->  the same link answers 200 with the same bytes.

Everything is timed. The scratch database is dropped at the end. Nothing in the
live database is changed.

Usage: python scripts/verify_backup_restore.py   (dev stack up, practice seeded
by scripts/seed_web_journeys.py)
"""
import base64
import json
import secrets
import subprocess
import sys
import time
from pathlib import Path

import requests
from urllib.parse import unquote, urlsplit

D = json.loads((Path(__file__).resolve().parents[1] / "build" / "web-journeys" / "defines.json").read_text(encoding="utf-8"))
BASE = D["API_BASE_URL"]
SCRATCH = "steriqore_restore_drill"
TABLES = ["tenants", "users", "cycles", "cycle_items", "labels", "prosthetic_cases", "audit_events",
          "products", "batches", "stock_movements", "patients", "purchase_orders"]
PNG = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")
FAILED = []
TIMES = {}


def check(label, ok, detail=""):
    print(("PASS  " if ok else "FAIL  ") + label + (f"  ({detail})" if detail else ""))
    if not ok:
        FAILED.append(label)


def sh(*cmd, timeout=900):
    return subprocess.run(list(cmd), capture_output=True, text=True, timeout=timeout, encoding="utf-8", errors="replace")


def app(*args, timeout=900):
    return sh("docker", "exec", "steriqore-app", *args, timeout=timeout)


def tinker(php, timeout=300):
    return app("php", "artisan", "tinker", "--execute=" + php, timeout=timeout).stdout


def psql(db, sql):
    r = sh("docker", "exec", "steriqore-postgres", "psql", "-U", "steriqore", "-d", db, "-tAc", sql)
    return r.stdout.strip(), r.stderr.strip()


def counts(db):
    out = {}
    for t in TABLES:
        val, err = psql(db, f"select count(*) from {t}")
        out[t] = int(val) if val.isdigit() else None
    return out


def timed(name, fn):
    start = time.perf_counter()
    result = fn()
    TIMES[name] = time.perf_counter() - start
    return result


def main():
    # ---- a real photo whose link we can watch
    r = requests.post(BASE + "/v1/auth/login", headers={"Idempotency-Key": secrets.token_hex(16)}, json={
        "tenant_slug": D["WEB_TENANT_SLUG"], "email": D["WEB_EMAIL_OWNER"], "password": D["WEB_PASSWORD"]})
    h = {"Authorization": "Bearer " + r.json()["token"], "Accept": "application/json"}
    device = requests.get(BASE + "/v1/devices?limit=1", headers=h).json()["data"][0]["id"]
    cyc = requests.post(BASE + "/v1/cycles", headers={**h, "Idempotency-Key": secrets.token_hex(16)}, json={"device_id": device}).json()
    cyc_id = (cyc.get("data") or cyc)["id"]
    up = requests.post(BASE + f"/v1/cycles/{cyc_id}/attachments-base64", headers={**h, "Idempotency-Key": secrets.token_hex(16)},
                       json={"file_name": "drill.png", "file_data": base64.b64encode(PNG).decode()})
    check("a real photo is stored before the backup", up.status_code == 201, str(up.status_code))
    att_id = up.json()["id"]

    def link():
        rows = requests.get(BASE + f"/v1/cycles/{cyc_id}/attachments", headers=h).json()
        rows = rows.get("data", rows) if isinstance(rows, dict) else rows
        return next(x["url"] for x in rows if x["id"] == att_id)

    check("its link opens", requests.get(link(), timeout=30).content == PNG)

    # ---- DATABASE: back up
    print("== database")
    live = counts("steriqore")
    check("live counts read", all(v is not None for v in live.values()), str(live))
    out = timed("db_backup", lambda: app("php", "artisan", "backup:run", "--only-db"))
    check("backup:run --only-db succeeded", out.returncode == 0, (out.stdout + out.stderr).strip()[-160:])

    # ---- DATABASE: read the newest dump back from the bucket and restore it
    php = (
        "$d=Storage::disk('backups');"
        "$f=collect($d->allFiles())->filter(fn($p)=>str_ends_with($p,'.zip') && !str_contains($p,'media-backup') && !str_contains($p,'data-exports'))"
        "->sortByDesc(fn($p)=>$d->lastModified($p))->first();"
        "file_put_contents('/tmp/drill.zip',$d->get($f));echo 'DUMP='.$f.' BYTES='.filesize('/tmp/drill.zip');"
    )
    got = tinker(php)
    check("newest dump read back from the backups bucket", "DUMP=" in got and "BYTES=" in got, got.strip()[-120:])
    sh("docker", "exec", "steriqore-postgres", "psql", "-U", "steriqore", "-d", "postgres", "-c", f"drop database if exists {SCRATCH}")
    mk = sh("docker", "exec", "steriqore-postgres", "psql", "-U", "steriqore", "-d", "postgres", "-c", f"create database {SCRATCH}")
    check("scratch database created", mk.returncode == 0, mk.stderr.strip()[-100:])

    def restore():
        found = tinker(
            "$z=new ZipArchive;$z->open('/tmp/drill.zip');$z->extractTo('/tmp/drill');"
            "echo 'SQL='.collect(glob('/tmp/drill/db-dumps/*.sql'))->first();"
        )
        sql = found.split("SQL=")[1].strip() if "SQL=" in found else ""
        sh("docker", "cp", "steriqore-app:" + sql, "drill.sql")
        sh("docker", "cp", "drill.sql", "steriqore-postgres:/tmp/drill.sql")
        return sh("docker", "exec", "steriqore-postgres", "psql", "-U", "steriqore", "-d", SCRATCH,
                  "-v", "ON_ERROR_STOP=0", "-q", "-f", "/tmp/drill.sql", timeout=1800)

    res = timed("db_restore", restore)
    restored = counts(SCRATCH)
    # The dump was taken after the photo/cycle above; counts must match the live
    # database as it was at backup time (nothing else writes during the drill).
    now = counts("steriqore")
    same = all(restored[t] is not None and restored[t] >= live[t] and restored[t] <= now[t] for t in TABLES)
    check("restored row counts match the live database (every business table)", same,
          f"restored={restored} live_before={live}")
    # a tenant and its roles survived (the thing that broke in the first real drill)
    roles, _ = psql(SCRATCH, f"select count(*) from roles r join tenants t on t.id=r.tenant_id where t.slug='{D['WEB_TENANT_SLUG']}'")
    check("a restored practice still has its roles", roles.isdigit() and int(roles) >= 6, roles)
    sh("docker", "exec", "steriqore-postgres", "psql", "-U", "steriqore", "-d", "postgres", "-c", f"drop database if exists {SCRATCH}")
    app("rm", "-rf", "/tmp/drill", "/tmp/drill.zip")
    for p in ("drill.sql",):
        Path(p).unlink(missing_ok=True)

    # ---- MEDIA
    print("== media")
    out = timed("media_backup", lambda: app("php", "artisan", "steriqore:backup-media"))
    check("steriqore:backup-media succeeded", out.returncode == 0, (out.stdout + out.stderr).strip()[-160:])
    url = link()
    # the object key is the link's path without the bucket segment
    parts = urlsplit(url).path.lstrip("/").split("/", 1)
    rel, disk = (unquote(parts[1]) if len(parts) == 2 else ""), "media"
    check("the stored object is located", bool(rel), rel)
    tinker(f"Storage::disk('{disk}')->delete('{rel}');echo 'DELETED';")
    check("after deleting the file its link answers 404", requests.get(url, timeout=30).status_code == 404)
    out = timed("media_restore", lambda: tinker(
        "app(App\\Domain\\Compliance\\Actions\\RestoreMediaBackupAction::class)->execute();echo 'RESTORED';"))
    check("RestoreMediaBackupAction ran", "RESTORED" in out, out.strip()[-120:])
    back = requests.get(link(), timeout=30)
    check("the restored file opens again with the same bytes", back.status_code == 200 and back.content == PNG, str(back.status_code))

    print("\ntimings: " + ", ".join(f"{k} {v:.1f}s" for k, v in TIMES.items()))
    if FAILED:
        print("FAILED:", FAILED)
        sys.exit(1)
    print("ALL PASS")


if __name__ == "__main__":
    main()
