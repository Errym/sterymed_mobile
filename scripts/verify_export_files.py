"""
Live proof that a data export keeps EVERY attachment, even when two have the
same file name, and lists each one with a checksum.

Before the fix the export wrote files/<original name>, so two photos both
called IMG_0001.jpg overwrote each other and one piece of evidence vanished
from a legal archive without any error.

Steps (dev stack only): register a throwaway practice, create a device and a
cycle, attach two DIFFERENT files with the SAME name, request an export, wait
for it, download the archive and check it.

Usage: python scripts/verify_export_files.py
"""
import base64
import hashlib
import io
import json
import secrets
import subprocess
import sys
import time
import zipfile

import requests

BASE = "http://localhost:8010/api"
FAILED = []


def uuid_v4():
    b = bytearray(secrets.token_bytes(16))
    b[6] = (b[6] & 0x0F) | 0x40
    b[8] = (b[8] & 0x3F) | 0x80
    h = b.hex()
    return f"{h[:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:]}"


def check(label, ok, detail=""):
    print(("PASS  " if ok else "FAIL  ") + label + (f"  ({detail})" if detail else ""))
    if not ok:
        FAILED.append(label)


def call(method, path, token=None, **kwargs):
    headers = {"Idempotency-Key": uuid_v4()} if method in ("POST", "PUT") else {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return requests.request(method, BASE + path, headers=headers, timeout=60, **kwargs)


def png(rgb):
    """A valid 1x1 PNG of one colour, built by hand (no imaging library)."""
    import struct
    import zlib

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    raw = bytes([0]) + bytes(rgb)  # filter byte 0, then one RGB pixel
    signature = bytes([0x89]) + b"PNG" + bytes([0x0D, 0x0A, 0x1A, 0x0A])
    return (signature + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def main():
    slug = "zz-exp-" + secrets.token_hex(3)
    password = "Zz-" + secrets.token_urlsafe(14)
    email = f"owner-{slug}@example.com"
    r = call("POST", "/v1/tenants", json={
        "tenant_name": "ZZ Export Cabinet", "tenant_slug": slug,
        "owner_name": "Owner Export", "owner_email": email, "password": password,
    })
    check("1. practice registers", r.status_code in (200, 201), str(r.status_code))
    if r.status_code not in (200, 201):
        print(r.text[:300])
        sys.exit(1)
    token = call("POST", "/v1/auth/login", json={"tenant_slug": slug, "email": email, "password": password}).json()["token"]

    php = (
        "$t=App\\Domain\\Tenancy\\Models\\Tenant::where('slug','%s')->first();"
        "App\\Support\\Tenancy\\TenantContext::run($t,function() use($t){"
        "$t->sites()->firstOrCreate(['name'=>'Cabinet Principal']);});echo 'ok';" % slug
    )
    out = subprocess.run(["docker", "exec", "steriqore-app", "php", "artisan", "tinker", "--execute=" + php],
                         capture_output=True, text=True, timeout=120)
    check("2. (web step) site created", "ok" in out.stdout, out.stdout.strip()[-60:])
    site_id = call("GET", "/v1/sites", token).json()
    site_id = (site_id["data"] if isinstance(site_id, dict) else site_id)[0]["id"]

    device = call("POST", "/v1/devices", token, json={
        "site_id": site_id, "name": "Autoclave Export", "serial_number": "SN-" + secrets.token_hex(4)})
    check("3. device created", device.status_code == 201, str(device.status_code))
    cycle = call("POST", "/v1/cycles", token, json={"device_id": device.json()["id"]})
    check("4. cycle created", cycle.status_code == 201, str(cycle.status_code))
    cycle_id = cycle.json()["id"]

    # Two genuinely different, valid PNGs (the server only accepts real images)
    # carrying the SAME file name.
    contents = [png((255, 0, 0)), png((0, 0, 255))]
    for i, body in enumerate(contents, 1):
        r = call("POST", f"/v1/cycles/{cycle_id}/attachments-base64", token, json={
            "file_name": "IMG_0001.png", "file_data": base64.b64encode(body).decode()})
        check(f"5.{i} attachment 'IMG_0001.png' #{i} stored", r.status_code in (200, 201), f"{r.status_code} {r.text[:100]}")

    r = call("POST", "/v1/data-export-requests", token, json={})
    check("6. export requested", r.status_code in (200, 201, 202), f"{r.status_code} {r.text[:120]}")
    export_id = r.json()["id"]

    status = None
    for _ in range(40):
        status = call("GET", f"/v1/data-export-requests/{export_id}", token).json()
        if status.get("status") in ("completed", "failed"):
            break
        time.sleep(3)
    check("7. export completes", status.get("status") == "completed", str(status.get("status")) + " " + str(status.get("error")))
    check("8. the export counts both files", status.get("file_count") == 2, f"file_count={status.get('file_count')}")

    dl = call("POST", f"/v1/data-export-requests/{export_id}/download", token)
    url = dl.json().get("url") or dl.json().get("download_url")
    check("9. download link minted", dl.status_code == 200 and bool(url), str(dl.status_code))
    # The presigned link may name the internal storage host: swap it for the published one.
    url = url.replace("minio:9000", "localhost:9023").replace("://minio:", "://localhost:")
    archive = requests.get(url, timeout=60)
    check("10. archive downloads", archive.status_code == 200, str(archive.status_code))

    z = zipfile.ZipFile(io.BytesIO(archive.content))
    names = [n for n in z.namelist() if "/files/" in "/" + n or n.startswith("files/")]
    names = [n for n in names if not n.endswith("/")]
    check("11. BOTH same-named files are in the archive under different names", len(set(names)) == 2, str(names))
    found = sorted(z.read(n) for n in names)
    check("12. and their contents are intact, not overwritten", found == sorted(contents))

    manifest_name = next((n for n in z.namelist() if n.endswith("files_manifest.json")), None)
    check("13. the archive carries a files manifest", manifest_name is not None)
    if manifest_name:
        entries = json.loads(z.read(manifest_name))["files"]
        digests = {e["sha256"] for e in entries if e["status"] == "copied"}
        check("14. each entry has the right SHA-256",
              digests == {hashlib.sha256(c).hexdigest() for c in contents}, f"{len(entries)} entries")

    print()
    print("ALL PASS" if not FAILED else "FAILED: " + "; ".join(FAILED))
    sys.exit(1 if FAILED else 0)


if __name__ == "__main__":
    main()
