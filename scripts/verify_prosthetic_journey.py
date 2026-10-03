#!/usr/bin/env python3
"""
Live proof of the Phase 6 prosthetic workflow against the dev backend (the API
half of the prosthetic journey; the camera, the stopwatch run and the print
dialog are device steps, see docs/DEVICE_TEST_LOG.md).

Proves, with server read-back after every step:
  create (laboratory, patient, case) -> impression -> sent -> received ->
  scheduled -> placed, each transition readable in the history with its user,
  time and note; an invalid transition is refused with a French reason and the
  status does not change; moving a case through its statuses records the dates
  the waiting list depends on, so it appears there without any manual edit;
  every dashboard card equals the total of the list it opens (all seven);
  aging buckets are counted by the server over the whole waiting set; the
  remaining balance is the server's arithmetic (total - deposit received), a
  completed final payment means nothing owed, negative amounts are refused;
  a practitioner from ANOTHER clinic is refused, and that clinic cannot read or
  change this clinic's case; a read-only member can read but write nothing.

The read-only member is set up with `artisan tinker` (dev stack only),
standing in for the web admin action. Requires `pip install requests` and the
dev stack. Creates two throwaway practices named zz-e2e-<random>.

Usage: python scripts/verify_prosthetic_journey.py
"""
import secrets
import subprocess
import sys
import time
from datetime import date, timedelta

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


def call(method, path, token=None, key=None, **kwargs):
    headers = {"Accept": "application/json"}
    if method in ("POST", "PUT", "PATCH", "DELETE"):
        headers["Idempotency-Key"] = key or uuid_v4()
    if token:
        headers["Authorization"] = f"Bearer {token}"
    # The API rate-limits bursts (429). A proof script makes many calls in a
    # minute, so wait out the limit instead of reporting a false failure.
    for attempt in range(8):
        r = requests.request(method, BASE + path, headers=headers, timeout=60, **kwargs)
        if r.status_code != 429:
            return r
        time.sleep(float(r.headers.get("Retry-After", 8)))
    return r


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


def err_msg(r):
    try:
        return r.json()["error"]["message"]
    except Exception:
        return ""


def register(slug, name):
    password = "Zz-" + secrets.token_urlsafe(14)
    email = f"owner-{slug}@example.com"
    r = call("POST", "/v1/tenants", json={
        "tenant_name": name, "tenant_slug": slug,
        "owner_name": "Owner E2E", "owner_email": email, "password": password,
    })
    if r.status_code not in (200, 201):
        print("registration failed:", r.status_code, r.text[:300])
        sys.exit(1)
    login = call("POST", "/v1/auth/login", json={"tenant_slug": slug, "email": email, "password": password})
    token = login.json()["token"]
    me = call("GET", "/v1/me", token).json()["user"]
    return token, me["id"], password


def ensure_access(token):
    """BUG-026: a practice registered right after another can answer 403 on
    everything until the permission cache is reset. Reset and re-check so the
    proof below measures the prosthetic workflow, not that known defect."""
    for _ in range(4):
        if call("GET", "/v1/sites", token).status_code == 200:
            return
        subprocess.run(["docker", "exec", "steriqore-app", "php", "artisan", "permission:cache-reset"],
                       capture_output=True, text=True, timeout=60)


def list_all(token, query=""):
    """Every case the list returns, following the cursor to the end."""
    ids, cursor = [], None
    for _ in range(30):
        params = query + ("&" if query else "") + "limit=100"
        if cursor:
            params += "&cursor=" + cursor
        r = call("GET", "/v1/prosthetic-cases?" + params, token)
        if r.status_code != 200:
            return None
        body = r.json()
        ids += [row["id"] for row in body["data"]]
        cursor = body.get("meta", {}).get("next_cursor")
        if not cursor:
            break
    return ids


def new_case(token, practitioner, patient, **extra):
    return call("POST", "/v1/prosthetic-cases", token, json={
        "patient_id": patient, "practitioner_id": practitioner,
        "impression_type": "digital", "work_type": "crown",
        "impression_date": (date.today() - timedelta(days=20)).isoformat(), **extra,
    })


def main():
    slug = f"zz-e2e-{secrets.token_hex(3)}"
    # The second practice is registered first: only its owner id is needed until
    # the isolation checks at the very end (see ensure_access / BUG-026).
    other_token, other_owner_id, _ = register(f"{slug}-b", "ZZ E2E Autre")
    token, owner_id, password = register(slug, "ZZ E2E Prothese")
    ensure_access(token)
    check("1. practice registers and the owner signs in", bool(token))

    # ---- laboratory, patient, case
    lab = call("POST", "/v1/laboratories", token, json={"name": "Labo Dentaire"})
    check("2. laboratory created", lab.status_code in (200, 201), str(lab.status_code) + lab.text[:100])
    lab_id = lab.json().get("id")
    patient = call("POST", "/v1/patients", token, json={})
    check("   pseudonymous patient created", patient.status_code in (200, 201), str(patient.status_code))
    patient_id = patient.json()["id"]

    case = new_case(token, owner_id, patient_id, laboratory_id=lab_id, notes="Couronne 26")
    check("3. case created (status: impression completed)",
          case.status_code in (200, 201) and case.json()["status"] == "impression_completed",
          str(case.status_code) + case.text[:120])
    cid = case.json()["id"]

    foreign = new_case(token, other_owner_id, patient_id)
    check("   a practitioner from ANOTHER clinic is refused", foreign.status_code == 422, str(foreign.status_code))

    # ---- invalid transition: refused, French reason, status unchanged
    bad = call("POST", f"/v1/prosthetic-cases/{cid}/status", token, json={"status": "placed"})
    check("4. impression -> placed is refused (INVALID_STATUS_TRANSITION)",
          bad.status_code == 422 and err_code(bad) == "INVALID_STATUS_TRANSITION", err_code(bad))
    msg = err_msg(bad)
    check("   the reason is French and readable, not wire names",
          "Empreinte réalisée" in msg and "Posé" in msg and "impression_completed" not in msg, msg)
    check("   the status did not change",
          call("GET", f"/v1/prosthetic-cases/{cid}", token).json()["status"] == "impression_completed")

    # ---- the whole lifecycle with history read-back
    today = date.today().isoformat()
    sent = call("POST", f"/v1/prosthetic-cases/{cid}/status", token, json={"status": "sent_to_laboratory", "note": "Envoi DHL"})
    check("5. sent to laboratory", sent.status_code in (200, 201), str(sent.status_code))
    check("   the send date was recorded by the transition itself", sent.json().get("sent_to_lab_date") == today)

    check("   an at-laboratory case is NOT on the waiting list yet",
          cid not in (list_all(token, "scope=waiting_for_placement") or []))

    recv = call("POST", f"/v1/prosthetic-cases/{cid}/status", token, json={"status": "received_at_practice"})
    check("6. received at the practice", recv.status_code in (200, 201), str(recv.status_code))
    check("   the return date was recorded by the transition itself", recv.json().get("returned_from_lab_date") == today)
    check("   it now appears on the waiting list without any manual date edit",
          cid in (list_all(token, "scope=waiting_for_placement") or []))
    waiting = call("GET", "/v1/prosthetic-cases/waiting-placement", token).json()["data"]
    mine = [c for c in waiting if c["id"] == cid]
    check("   days elapsed come from the server (0 today)",
          bool(mine) and mine[0]["days_waiting_for_placement"] == 0, str(mine[:1])[:120])

    planned = (date.today() + timedelta(days=4)).isoformat()
    sched = call("POST", f"/v1/prosthetic-cases/{cid}/status", token,
                 json={"status": "placement_scheduled", "planned_placement_date": planned})
    check("7. placement scheduled with a planned date",
          sched.status_code in (200, 201) and sched.json().get("planned_placement_date") == planned, str(sched.status_code))

    placed = call("POST", f"/v1/prosthetic-cases/{cid}/status", token, json={"status": "placed", "note": "Posé sans retouche"})
    check("8. placed", placed.status_code in (200, 201) and placed.json()["status"] == "placed", str(placed.status_code))
    check("   the placement date was recorded", placed.json().get("actual_placement_date") == today)
    check("   a placed case leaves the waiting list",
          cid not in (list_all(token, "scope=waiting_for_placement") or []))

    history = call("GET", f"/v1/prosthetic-cases/{cid}/status-history", token).json()
    steps = [(h["from_status"], h["to_status"]) for h in reversed(history)]
    check("9. history shows creation and every transition, in the order they happened",
          steps == [(None, "impression_completed"),
                    ("impression_completed", "sent_to_laboratory"),
                    ("sent_to_laboratory", "received_at_practice"),
                    ("received_at_practice", "placement_scheduled"),
                    ("placement_scheduled", "placed")], str(steps))
    check("   each entry stores the user, the time and the note",
          all(h.get("changed_by_name") and h.get("created_at") for h in history)
          and {h["to_status"]: h.get("note") for h in history}.get("placed") == "Posé sans retouche"
          and {h["to_status"]: h.get("note") for h in history}.get("sent_to_laboratory") == "Envoi DHL")

    # ---- payment arithmetic is the server's
    pay = call("POST", "/v1/prosthetic-cases", token, json={
        "patient_id": patient_id, "practitioner_id": owner_id, "impression_type": "digital",
        "work_type": "bridge", "impression_date": today,
    }).json()["id"]
    r = call("PATCH", f"/v1/prosthetic-cases/{pay}", token, json={"total_amount": 1200.5})
    check("10. total 1200,50 -> the whole total is owed", r.json().get("remaining_balance") == 1200.5, str(r.json().get("remaining_balance")))
    r = call("PATCH", f"/v1/prosthetic-cases/{pay}", token, json={"deposit_requested": True, "deposit_amount": 300.25, "deposit_received": True})
    check("    deposit 300,25 received -> balance 900,25", r.json().get("remaining_balance") == 900.25, str(r.json().get("remaining_balance")))
    r = call("PATCH", f"/v1/prosthetic-cases/{pay}", token, json={"remaining_balance": 1})
    check("    a client-sent balance cannot override the arithmetic", r.json().get("remaining_balance") == 900.25)
    r = call("PATCH", f"/v1/prosthetic-cases/{pay}", token, json={"total_amount": -5})
    check("    a negative amount is refused", r.status_code == 422, str(r.status_code))
    r = call("PATCH", f"/v1/prosthetic-cases/{pay}", token, json={"final_payment_completed": True})
    check("    final payment completed -> nothing owed", r.json().get("remaining_balance") in (0, 0.0), str(r.json().get("remaining_balance")))

    # ---- every dashboard card equals the list it opens
    dash = call("GET", "/v1/prosthetic-dashboard", token).json()
    cards = {
        "active_cases": "active", "at_laboratory": "at_laboratory",
        "returned_to_practice": "returned_to_practice", "waiting_for_placement": "waiting_for_placement",
        "placements_today": "placements_today", "placements_this_week": "placements_this_week",
        "deposits_or_balances_due": "payments_due",
    }
    for field, scope in cards.items():
        ids = list_all(token, f"scope={scope}")
        summary = call("GET", f"/v1/prosthetic-cases/summary?scope={scope}", token).json()
        check(f"11. card '{field}' = list total = summary total",
              ids is not None and len(ids) == dash[field] == summary["total"],
              f"card={dash[field]} list={None if ids is None else len(ids)} summary={summary['total']}")

    # ---- aging buckets over the whole waiting set (beyond one page)
    ages = {2: 0, 10: 0, 20: 0}
    php_dates = []
    for days in (2, 10, 20):
        for _ in range(7):
            c = new_case(token, owner_id, patient_id)
            php_dates.append((c.json()["id"], days))
            ages[days] += 1
    for i, days in php_dates:
        d = (date.today() - timedelta(days=days)).isoformat()
        tinker(
            "App\\Support\\Tenancy\\TenantContext::run(App\\Domain\\Tenancy\\Models\\Tenant::where('slug','%s')->first(),"
            "function(){App\\Domain\\Prosthetic\\Models\\ProstheticCase::where('id','%s')->update("
            "['status'=>'received_at_practice','returned_from_lab_date'=>'%s']);});" % (slug, i, d)
        )
    summary = call("GET", "/v1/prosthetic-cases/summary?scope=waiting_for_placement", token).json()
    check("12. aging buckets are counted by the server over the whole set",
          summary["aging"] == {"fresh": 7, "medium": 7, "urgent": 7} and summary["total"] == 21,
          str(summary))
    urgent = call("GET", "/v1/prosthetic-cases/waiting-placement?aging=urgent&limit=100", token).json()["data"]
    check("    the 15+ day filter is applied by the server", len(urgent) == 7
          and all(c["days_waiting_for_placement"] >= 15 for c in urgent), str(len(urgent)))

    # ---- a read-only member
    viewer_email = f"viewer-{slug}@example.com"
    out = tinker(
        "$t=App\\Domain\\Tenancy\\Models\\Tenant::where('slug','%s')->first();"
        "App\\Support\\Tenancy\\TenantContext::run($t,function() use($t){"
        "$u=App\\Models\\User::create(['name'=>'Viewer E2E','email'=>'%s','password'=>Illuminate\\Support\\Facades\\Hash::make('%s')]);"
        "App\\Domain\\Identity\\Models\\TenantUser::create(['tenant_id'=>$t->id,'user_id'=>$u->id,'status'=>'active']);"
        "$r=app(Spatie\\Permission\\PermissionRegistrar::class);$r->setPermissionsTeamId($t->id);"
        "$u->assignRole('viewer');echo 'VIEWER_OK';});" % (slug, viewer_email, password)
    )
    check("14. (web step) read-only member created", "VIEWER_OK" in out, out[-120:])
    v = call("POST", "/v1/auth/login", json={"tenant_slug": slug, "email": viewer_email, "password": password})
    viewer = v.json().get("token")
    check("    read-only member signs in", v.status_code == 200 and bool(viewer))
    check("    reads the case list and the dashboard",
          call("GET", "/v1/prosthetic-cases", viewer).status_code == 200
          and call("GET", "/v1/prosthetic-dashboard", viewer).status_code == 200)
    check("    cannot create a case", call("POST", "/v1/prosthetic-cases", viewer, json={
        "patient_id": patient_id, "practitioner_id": owner_id, "impression_type": "digital",
        "work_type": "crown", "impression_date": today}).status_code == 403)
    check("    cannot change a status",
          call("POST", f"/v1/prosthetic-cases/{pay}/status", viewer, json={"status": "sent_to_laboratory"}).status_code == 403)
    check("    cannot edit payments",
          call("PATCH", f"/v1/prosthetic-cases/{pay}", viewer, json={"deposit_amount": 10}).status_code == 403)

    # ---- isolation: ANOTHER practice (last, because of BUG-026 the reset that
    # ---- unlocks it may lock the first practice out, which is no longer needed)
    ensure_access(other_token)
    check("13. another clinic cannot read this case",
          call("GET", f"/v1/prosthetic-cases/{cid}", other_token).status_code == 404)
    check("    ...nor change it",
          call("POST", f"/v1/prosthetic-cases/{cid}/status", other_token, json={"status": "cancelled"}).status_code == 404)
    check("    ...and does not see it in its own list or counts",
          cid not in (list_all(other_token) or [])
          and call("GET", "/v1/prosthetic-dashboard", other_token).json().get("active_cases") == 0,
          call("GET", "/v1/prosthetic-dashboard", other_token).text[:160])

    print()
    if FAILED:
        print(f"{len(FAILED)} check(s) FAILED:")
        for f in FAILED:
            print("  -", f)
        sys.exit(1)
    print("ALL PASS")


if __name__ == "__main__":
    main()
