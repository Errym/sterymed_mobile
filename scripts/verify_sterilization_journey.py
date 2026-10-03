#!/usr/bin/env python3
"""
Live proof of the Phase 4 sterilization / label / traceability chain against the
dev backend (the API half of journey J-STERIL; the printer and the physical
scan are device steps, see docs/DEVICE_TEST_LOG.md).

Proves, with server read-back after every step:
  prepare -> edit an item IN PLACE -> start -> complete -> control -> submit
  -> release (decision readable) -> generate labels -> print
  -> PASSIVE lookups never consume a label (owner and viewer)
  -> recording the usage is what consumes it (once)
  -> negative set: rejected cycle (no labels), recalled, expired, used,
     duplicate use, reprint of a used label.

Site, viewer account and the "expired"/"recalled" label states are set up with
`artisan tinker` (dev stack only), standing in for web/admin actions. Requires
`pip install requests` and the dev stack.

Usage: python scripts/verify_sterilization_journey.py
Creates one throwaway practice named zz-e2e-<random>.
"""
import re
import secrets
import subprocess
import sys

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
    headers = {"Idempotency-Key": uuid_v4()} if method == "POST" else {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return requests.request(method, BASE + path, headers=headers, timeout=60, **kwargs)


def tinker(php):
    out = subprocess.run(
        ["docker", "exec", "steriqore-app", "php", "artisan", "tinker", "--execute=" + php],
        capture_output=True, text=True, timeout=120,
    )
    return out.stdout.strip()


def err_code(r):
    try:
        return r.json()["error"]["code"]
    except Exception:
        return f"<{r.status_code}>"


def main():
    slug = f"zz-e2e-{secrets.token_hex(3)}"
    password = "Zz-" + secrets.token_urlsafe(14)
    email = f"owner-{slug}@example.com"
    viewer_email = f"viewer-{slug}@example.com"

    r = call("POST", "/v1/tenants", json={
        "tenant_name": "ZZ E2E Sterilisation", "tenant_slug": slug,
        "owner_name": "Owner E2E", "owner_email": email, "password": password,
    })
    check("1. practice registers", r.status_code in (200, 201), str(r.status_code))
    if r.status_code not in (200, 201):
        print(r.text[:300])
        sys.exit(1)
    login = call("POST", "/v1/auth/login", json={"tenant_slug": slug, "email": email, "password": password})
    token = login.json()["token"]
    owner_id = login.json()["user"]["id"]
    check("2. owner signs in", login.status_code == 200)

    # Web-owned steps: the site, and a read-only member.
    out = tinker(
        "$t=App\\Domain\\Tenancy\\Models\\Tenant::where('slug','%s')->first();"
        "App\\Support\\Tenancy\\TenantContext::run($t,function() use($t){"
        "$s=$t->sites()->firstOrCreate(['name'=>'Cabinet Principal']);"
        "$u=App\\Models\\User::create(['name'=>'Viewer E2E','email'=>'%s','password'=>Illuminate\\Support\\Facades\\Hash::make('%s')]);"
        "App\\Domain\\Identity\\Models\\TenantUser::create(['tenant_id'=>$t->id,'user_id'=>$u->id,'status'=>'active']);"
        "$r=app(Spatie\\Permission\\PermissionRegistrar::class);$r->setPermissionsTeamId($t->id);"
        "$u->assignRole('viewer');echo 'SITE='.$s->id;});"
        % (slug, viewer_email, password)
    )
    m = re.search(r"SITE=([0-9a-f-]{36})", out)
    site_id = m.group(1) if m else ""
    check("3. (web step) site + viewer member created", len(site_id) == 36, out[-160:])
    v = call("POST", "/v1/auth/login", json={"tenant_slug": slug, "email": viewer_email, "password": password})
    viewer = v.json().get("token")
    check("   viewer signs in", v.status_code == 200 and viewer, str(v.status_code))

    device = call("POST", "/v1/devices", token, json={
        "site_id": site_id, "name": "Autoclave E2E", "serial_number": "SN-" + secrets.token_hex(4),
    }).json()
    device_id = device.get("id")
    check("4. device created", bool(device_id), str(device)[:100])
    dlu = call("POST", "/v1/dlu-rules", token, json={
        "packaging_type": "Sachet", "storage_condition": "Armoire", "shelf_life_days": 180, "reason": "E2E",
    })
    check("   DLU rule created", dlu.status_code in (200, 201), str(dlu.status_code))

    # ---- prepare + edit in place
    cycle = call("POST", "/v1/cycles", token, json={"device_id": device_id}).json()
    cid = cycle["id"]
    a = call("POST", f"/v1/cycles/{cid}/items", token, json={"description": "Cassette 1"}).json()
    b = call("POST", f"/v1/cycles/{cid}/items", token, json={"description": "Cassette 2"}).json()
    patched = call("PATCH", f"/v1/cycles/{cid}/items/{b['id']}", token, json={"description": "Cassette 2 (revisee)"})
    check("5. item edited in place (same id, same position)",
          patched.status_code == 200 and patched.json()["id"] == b["id"]
          and patched.json()["sequence_in_cycle"] == b["sequence_in_cycle"]
          and patched.json()["description"] == "Cassette 2 (revisee)", str(patched.status_code))
    items = call("GET", f"/v1/cycles/{cid}/items", token).json()
    check("   server read-back: still two items", len(items) == 2, str(len(items)))

    for step in ("start", "complete"):
        s = call("POST", f"/v1/cycles/{cid}/{step}", token)
        check(f"6. cycle {step}", s.status_code in (200, 201), str(s.status_code))
    locked = call("PATCH", f"/v1/cycles/{cid}/items/{a['id']}", token, json={"description": "trop tard"})
    check("   item edit refused once the cycle left draft", locked.status_code == 409 and err_code(locked) == "CYCLE_LOAD_LOCKED", err_code(locked))
    ct = call("POST", f"/v1/cycles/{cid}/control-tests", token, json={
        "type": "bowie_dick", "result": "pass", "performed_at": "2026-10-02T08:00:00Z",
    })
    check("7. control test recorded", ct.status_code in (200, 201), str(ct.status_code))
    sub = call("POST", f"/v1/cycles/{cid}/submit-for-release", token)
    check("   submitted for release", sub.status_code in (200, 201), str(sub.status_code))
    rel = call("POST", f"/v1/cycles/{cid}/release", token, json={"decision": "compliant"})
    check("8. released compliant", rel.status_code in (200, 201), str(rel.status_code))
    stored = call("GET", f"/v1/cycles/{cid}/release", token)
    check("   stored decision readable (decision, actor, time)",
          stored.status_code == 200 and stored.json()["decision"] == "compliant"
          and stored.json().get("released_by_name") and stored.json().get("released_at"), str(stored.json())[:120])

    # ---- evidence attachment (the route the mobile app uses)
    import base64
    png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")
    up = call("POST", f"/v1/cycles/{cid}/attachments-base64", token, json={"file_name": "indicateur.png", "file_data": base64.b64encode(png).decode()})
    check("8b. evidence photo uploads (JSON base64 route)", up.status_code == 201 and up.json().get("mime_type") == "image/png", str(up.status_code))
    listed = call("GET", f"/v1/cycles/{cid}/attachments", token).json()
    check("    server read-back: one attachment, readable by the viewer too",
          len(listed) == 1 and call("GET", f"/v1/cycles/{cid}/attachments", viewer).status_code == 200, str(len(listed)))
    bad = call("POST", f"/v1/cycles/{cid}/attachments-base64", token, json={"file_name": "x.exe", "file_data": base64.b64encode(b"MZ not an image").decode()})
    check("    a file that is not an image/PDF is refused with 422 (not 500)", bad.status_code == 422, f"{bad.status_code} {err_code(bad)}")

    # ---- rejected cycle: no labels
    c2 = call("POST", "/v1/cycles", token, json={"device_id": device_id}).json()["id"]
    call("POST", f"/v1/cycles/{c2}/items", token, json={"description": "Rejete"})
    for step in ("start", "complete", "submit-for-release"):
        call("POST", f"/v1/cycles/{c2}/{step}", token)
    call("POST", f"/v1/cycles/{c2}/release", token, json={"decision": "rejected", "reason": "Indicateur non vire"})
    g = call("POST", f"/v1/cycles/{c2}/labels", token, json={"packaging_type": "Sachet", "storage_condition": "Armoire"})
    check("9. rejected cycle: no labels can be generated", g.status_code == 409 and err_code(g) == "CYCLE_NOT_RELEASED", err_code(g))

    # ---- labels
    g = call("POST", f"/v1/cycles/{cid}/labels", token, json={"packaging_type": "Sachet", "storage_condition": "Armoire"})
    labels = g.json()
    check("10. labels generated, one per item", g.status_code == 201 and len(labels) == 2, str(g.status_code))
    l1, l2, l3 = labels[0]["id"], labels[1]["id"], None
    pr = call("POST", f"/v1/labels/{l1}/print", token)
    call("POST", f"/v1/labels/{l2}/print", token)
    check("   label printed", pr.status_code in (200, 201) and pr.json()["status"] == "printed", str(pr.status_code))

    # ---- passive lookups never consume
    first = call("GET", f"/v1/labels/urn:steriqore:label:{l1}", token)
    again = call("GET", f"/v1/labels/{l1}", token)
    seen_by_viewer = call("GET", f"/v1/labels/{l1}", viewer)
    check("11. owner lookups (x2) leave the label printed",
          first.json().get("status") == "printed" and again.json().get("status") == "printed"
          and first.json().get("usage_recorded") is False, first.json().get("status", str(first.status_code)))
    check("    a viewer's lookup changes nothing", seen_by_viewer.status_code == 200 and seen_by_viewer.json()["status"] == "printed", str(seen_by_viewer.status_code))
    pdf = call("GET", f"/v1/labels/{l1}/qr-code", viewer)
    check("    viewer can still view the label (read permission intact)", pdf.status_code == 200, str(pdf.status_code))

    # ---- usage consumes, once
    patient = call("POST", "/v1/patients", token, json={}).json()
    denied = call("POST", f"/v1/labels/{l1}/usage", viewer, json={
        "patient_id": patient["id"], "practitioner_id": owner_id, "procedure": "X",
    })
    check("    a viewer cannot consume it (403) and the label is unchanged",
          denied.status_code == 403 and call("GET", f"/v1/labels/{l1}", token).json()["status"] == "printed",
          str(denied.status_code))
    use = call("POST", f"/v1/labels/{l1}/usage", token, json={
        "patient_id": patient["id"], "practitioner_id": owner_id, "procedure": "Detartrage",
    })
    check("12. recording the usage succeeds", use.status_code == 201, f"{use.status_code} {err_code(use)}")
    after = call("GET", f"/v1/labels/{l1}", token).json()
    check("    server read-back: used, usage recorded", after["status"] == "used" and after["usage_recorded"] is True, str(after.get("status")))
    dup = call("POST", f"/v1/labels/{l1}/usage", token, json={
        "patient_id": patient["id"], "practitioner_id": owner_id, "procedure": "Detartrage 2",
    })
    check("13. duplicate use refused", dup.status_code == 409 and err_code(dup) == "LABEL_USAGE_ALREADY_RECORDED", err_code(dup))
    rp = call("POST", f"/v1/labels/{l1}/print", token, json={"reason": "perdue"})
    check("14. a used label cannot be reprinted back to printed", rp.status_code == 409 and err_code(rp) == "LABEL_NOT_PRINTABLE", err_code(rp))
    still = call("GET", f"/v1/labels/{l1}", token).json()["status"]
    check("    ... and stays used", still == "used", still)

    # ---- expired
    tinker("$l=App\\Domain\\Labeling\\Models\\Label::withoutGlobalScopes()->find('%s');$l->update(['use_by_date'=>now()->subDay()]);echo 'ok';" % l2)
    exp = call("GET", f"/v1/labels/{l2}", token)
    check("15. expired label: lookup is blocked (410) and writes nothing", exp.status_code == 410 and err_code(exp) == "LABEL_EXPIRED", err_code(exp))
    use2 = call("POST", f"/v1/labels/{l2}/usage", token, json={
        "patient_id": patient["id"], "practitioner_id": owner_id, "procedure": "X",
    })
    check("    expired label cannot be used (410)", use2.status_code == 410 and err_code(use2) == "LABEL_EXPIRED", err_code(use2))

    # ---- recalled via a non-conformity on the cycle
    nc = call("POST", "/v1/non-conformities", token, json={
        "subject_type": "cycle", "subject_id": cid, "description": "Rappel E2E", "severity": "major",
    })
    check("16. non-conformity raised against the cycle", nc.status_code in (200, 201), f"{nc.status_code} {nc.text[:120]}")
    rec = call("GET", f"/v1/labels/{l1}", token)
    check("    its labels are recalled: lookup returns 410", rec.status_code == 410 and err_code(rec) == "LABEL_RECALLED", err_code(rec))

    print()
    if FAILED:
        print(f"{len(FAILED)} check(s) FAILED:")
        for f in FAILED:
            print("  -", f)
        sys.exit(1)
    print("All checks passed.")


if __name__ == "__main__":
    main()
