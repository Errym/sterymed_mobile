#!/usr/bin/env python3
"""
T8.1 — authorization matrix, proven against the dev backend.

Practice A is the one seeded by scripts/seed_web_journeys.py (one user per
role). Practice B is registered here. For every role of A the script probes
real routes whose required permission is written down below, and checks BOTH
directions:

  * a role WITHOUT the permission is answered 403 (a request with an empty body
    is used for writes, so a role WITH the permission is answered 422/404, never
    403: authorization is decided before validation);
  * a role WITH the permission is never answered 403 / 401.

Then the tenant wall: B's owner (full rights in B) cannot read or change any
resource of A, by id, and A's lists never contain B's rows and vice versa.
Finally "permission changed mid-session": a practitioner is demoted to viewer
and the SAME token loses write access on the next request.

The permission table below is a copy of SeedTenantRolesAction::PERMISSIONS_BY_ROLE
(re-read on 2 Oct 2026); if the backend changes it, this script must change too.

Usage: python scripts/verify_authorization_matrix.py   (seed first)
"""
import json
import secrets
import subprocess
import sys
import time
from pathlib import Path

import requests

DEFINES = Path(__file__).resolve().parents[1] / "build" / "web-journeys" / "defines.json"
FAILED = []
ROLES = ["owner", "admin", "stock_manager", "releaser", "practitioner", "viewer"]

READ_ALL = ["sites.view", "products.view", "suppliers.view", "purchasing.view", "inventory.view",
            "alerts.view", "devices.view", "cycles.view", "labels.view", "patients.view",
            "usages.view", "non_conformities.view", "prosthetic_cases.view"]
GRANTS = {
    "stock_manager": READ_ALL + ["products.manage", "suppliers.manage", "purchasing.manage",
                                 "inventory.manage", "alerts.manage", "devices.manage",
                                 "cycles.manage", "labels.manage"],
    "releaser": READ_ALL + ["cycles.release", "non_conformities.manage"],
    "practitioner": READ_ALL + ["patients.manage", "usages.manage", "prosthetic_cases.manage"],
    "viewer": READ_ALL,
}
# owner / admin hold every permission (owner also evidence_settings.manage).
ALL = set(READ_ALL) | {"products.manage", "suppliers.manage", "purchasing.manage", "inventory.manage",
                       "alerts.manage", "devices.manage", "cycles.manage", "cycles.release",
                       "labels.manage", "patients.manage", "usages.manage", "exports.manage",
                       "non_conformities.manage", "data_exports.manage", "practice_settings.manage",
                       "prosthetic_cases.manage", "prosthetic_payments.manage", "invitations.create",
                       "audit.view", "sites.manage", "evidence_settings.manage"}


def has(role, perm):
    if role == "owner":
        return True
    if role == "admin":
        return perm != "evidence_settings.manage"
    return perm in GRANTS[role]


# (method, path, permission required, body factory). A write carries a VALID
# body: several endpoints validate before they authorize, so an empty body
# would be answered 422 whatever the role and prove nothing.
def _uniq():
    return secrets.token_hex(3).upper()


PROBES = [
    ("GET", "/v1/sites", "sites.view", None),
    ("GET", "/v1/products", "products.view", None),
    ("GET", "/v1/suppliers", "suppliers.view", None),
    ("GET", "/v1/purchase-orders", "purchasing.view", None),
    ("GET", "/v1/stock-levels", "inventory.view", None),
    ("GET", "/v1/alerts", "alerts.view", None),
    ("GET", "/v1/devices", "devices.view", None),
    ("GET", "/v1/cycles", "cycles.view", None),
    ("GET", "/v1/patients", "patients.view", None),
    ("GET", "/v1/non-conformities", "non_conformities.view", None),
    ("GET", "/v1/audit-events", "audit.view", None),
    ("GET", "/v1/prosthetic-cases", "prosthetic_cases.view", None),
    ("GET", "/v1/prosthetic-dashboard", "prosthetic_cases.view", None),
    ("GET", "/v1/data-export-requests", "data_exports.manage", None),
    ("POST", "/v1/products", "products.manage",
     lambda c: {"name": "Probe " + _uniq(), "reference": "PR-" + _uniq(), "unit": "boite"}),
    ("POST", "/v1/suppliers", "suppliers.manage", lambda c: {"name": "Probe " + _uniq()}),
    ("POST", "/v1/purchase-orders", "purchasing.manage",
     lambda c: {"supplier_id": c["supplier"], "lines": [{"product_id": c["product"], "qty_ordered": 1, "unit_price": 1}]}),
    ("POST", "/v1/stock-movements/issue", "inventory.manage",
     lambda c: {"batch_id": c["batch"], "location_id": c["location"], "qty": 1}),
    ("POST", "/v1/stock-movements/adjust", "inventory.manage",
     lambda c: {"batch_id": c["batch"], "location_id": c["location"], "qty": 1, "reason": "probe"}),
    ("POST", "/v1/stock-movements/transfer", "inventory.manage",
     lambda c: {"batch_id": c["batch"], "from_location_id": c["location"], "to_location_id": c["location2"], "qty": 1}),
    ("POST", "/v1/inventory-counts", "inventory.manage", lambda c: {"location_id": c["location"]}),
    ("POST", "/v1/devices", "devices.manage",
     lambda c: {"site_id": c["site"], "name": "Probe " + _uniq(), "serial_number": "SN-" + _uniq()}),
    ("POST", "/v1/cycles", "cycles.manage", lambda c: {"device_id": c["device"]}),
    ("POST", "/v1/patients", "patients.manage", lambda c: {}),
    ("POST", "/v1/prosthetic-cases", "prosthetic_cases.manage",
     lambda c: {"patient_id": c["patient"], "practitioner_id": c["practitioner"], "impression_type": "digital",
                "work_type": "crown", "impression_date": time.strftime("%Y-%m-%d")}),
    ("POST", "/v1/laboratories", "prosthetic_cases.manage", lambda c: {"name": "Probe " + _uniq()}),
    ("POST", "/v1/invitations", "invitations.create",
     lambda c: {"email": f"probe-{_uniq().lower()}@example.com", "role": "viewer"}),
    ("POST", "/v1/non-conformities", "non_conformities.manage",
     lambda c: {"subject_type": "cycle", "subject_id": c["cycle"], "description": "probe"}),
    ("POST", "/v1/data-export-requests", "data_exports.manage", lambda c: {}),
]


def uuid_v4():
    b = bytearray(secrets.token_bytes(16))
    b[6] = (b[6] & 0x0F) | 0x40
    b[8] = (b[8] & 0x3F) | 0x80
    h = b.hex()
    return f"{h[:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:]}"


D = json.loads(DEFINES.read_text(encoding="utf-8"))
BASE = D["API_BASE_URL"]


def check(label, ok, detail=""):
    print(("PASS  " if ok else "FAIL  ") + label + (f"  ({detail})" if detail else ""))
    if not ok:
        FAILED.append(label)


def call(method, path, token=None, **kw):
    headers = {"Accept": "application/json"}
    if method in ("POST", "PUT", "PATCH", "DELETE"):
        headers["Idempotency-Key"] = uuid_v4()
    if token:
        headers["Authorization"] = f"Bearer {token}"
    for _ in range(8):
        r = requests.request(method, BASE + path, headers=headers, timeout=60, **kw)
        if r.status_code == 429:  # the API's own rate limit: wait, never count it
            time.sleep(float(r.headers.get("Retry-After", "5")) + 0.5)
            continue
        return r
    return r


def login(slug, email, password):
    r = call("POST", "/v1/auth/login", json={"tenant_slug": slug, "email": email, "password": password})
    r.raise_for_status()
    return r.json()["token"]


def cache_reset():
    subprocess.run(["docker", "exec", "steriqore-app", "php", "artisan", "permission:cache-reset"],
                   capture_output=True, text=True, timeout=60)


def tinker(php):
    return subprocess.run(["docker", "exec", "steriqore-app", "php", "artisan", "tinker", "--execute=" + php],
                          capture_output=True, text=True, timeout=120).stdout.strip()


def set_role(slug, email, role):
    """Changes a member's role the way the web admin would (inside the tenant context, roles are RLS-protected)."""
    return tinker(
        rf"$t=\App\Domain\Tenancy\Models\Tenant::where('slug','{slug}')->first();"
        rf"$u=\App\Models\User::where('email','{email}')->first();"
        rf"\App\Support\Tenancy\TenantContext::run($t, fn () => $u->syncRoles(['{role}']));echo 'ROLE_OK';"
    )


def first_id(token, path):
    body = call("GET", path, token).json()
    rows = body.get("data", []) if isinstance(body, dict) else body
    return rows[0]["id"] if rows else None


def throwaway_cycle(owner):
    """A fresh draft cycle with no labels, so the non-conformity probe can never
    recall the seeded practice's labels and spoil the journeys that follow."""
    device = first_id(owner, "/v1/devices")
    r = call("POST", "/v1/cycles", owner, json={"device_id": device})
    body = r.json()
    return (body.get("data") or body)["id"]


def build_context(owner):
    """Real ids of practice A that the write probes need."""
    levels = call("GET", "/v1/stock-levels?limit=50", owner).json().get("data", [])
    with_stock = next((x for x in levels if x["quantity"] > 0), levels[0])
    locations = call("GET", "/v1/locations", owner).json()
    locations = locations.get("data", []) if isinstance(locations, dict) else locations
    other = next((x["id"] for x in locations if x["id"] != with_stock["location_id"]), with_stock["location_id"])
    return {
        "site": first_id(owner, "/v1/sites"), "device": first_id(owner, "/v1/devices"),
        "supplier": first_id(owner, "/v1/suppliers"), "product": first_id(owner, "/v1/products"),
        "batch": with_stock["batch_id"], "location": with_stock["location_id"], "location2": other,
        "patient": D["WEB_PATIENT_ID"], "practitioner": call("GET", "/v1/me", owner).json()["user"]["id"],
        "cycle": throwaway_cycle(owner),
    }


def main():
    slug, pw = D["WEB_TENANT_SLUG"], D["WEB_PASSWORD"]
    emails = {
        "owner": D["WEB_EMAIL_OWNER"], "admin": D["WEB_EMAIL_ADMIN"],
        "stock_manager": D["WEB_EMAIL_STOCK_MANAGER"], "releaser": D["WEB_EMAIL_RELEASER"],
        "practitioner": D["WEB_EMAIL_PRACTITIONER"], "viewer": D["WEB_EMAIL_VIEWER"],
    }
    cache_reset()  # BUG-026: a stale permission cache would measure the cache, not the matrix
    tokens = {role: login(slug, email, pw) for role, email in emails.items()}

    print("== 1. role x route matrix (practice A)")
    ctx = build_context(tokens["owner"])
    for role in ROLES:
        wrong = []
        for method, path, perm, body in PROBES:
            kw = {"json": body(ctx)} if body else ({"json": {}} if method == "POST" else {})
            r = call(method, path, tokens[role], **kw)
            allowed = has(role, perm)
            if allowed and r.status_code in (401, 403):
                wrong.append(f"{method} {path} refused {r.status_code} but {role} holds {perm}")
            if not allowed and r.status_code != 403:
                wrong.append(f"{method} {path} answered {r.status_code}, expected 403 ({role} lacks {perm})")
        check(f"{role}: all {len(PROBES)} probes match the grants", not wrong, "; ".join(wrong[:3]))

    print("== 2. tenant wall (practice B cannot touch practice A)")
    owner_a = tokens["owner"]
    ids = {
        "products": first_id(owner_a, "/v1/products"),
        "suppliers": first_id(owner_a, "/v1/suppliers"),
        "cycles": first_id(owner_a, "/v1/cycles"),
        "purchase-orders": D.get("WEB_PO_ID") or first_id(owner_a, "/v1/purchase-orders"),
        "devices": first_id(owner_a, "/v1/devices"),
        "laboratories": first_id(owner_a, "/v1/laboratories"),
    }
    patient_id = D.get("WEB_PATIENT_ID")
    practitioner_id = call("GET", "/v1/me", owner_a).json()["user"]["id"]
    case = call("POST", "/v1/prosthetic-cases", owner_a, json={
        "patient_id": patient_id, "practitioner_id": practitioner_id,
        "impression_type": "digital", "work_type": "crown", "impression_date": time.strftime("%Y-%m-%d"),
    })
    ids["prosthetic-cases"] = case.json().get("data", case.json()).get("id") if case.status_code < 300 else None

    slug_b = "zz-authz-" + secrets.token_hex(3)
    pw_b = "Zz-" + secrets.token_urlsafe(14)
    reg = call("POST", "/v1/tenants", json={"tenant_name": "Authz B " + slug_b, "tenant_slug": slug_b,
                                            "owner_name": "Owner B", "owner_email": f"owner-{slug_b}@example.com",
                                            "password": pw_b})
    check("practice B registered", reg.status_code in (200, 201), str(reg.status_code))
    cache_reset()
    owner_b = login(slug_b, f"owner-{slug_b}@example.com", pw_b)
    check("B's owner has full rights in B", call("GET", "/v1/sites", owner_b).status_code == 200)

    for kind, rid in ids.items():
        if not rid:
            check(f"A has a {kind} to probe", False, "nothing seeded")
            continue
        r = call("GET", f"/v1/{kind}/{rid}", owner_b)
        check(f"B cannot read A's {kind} by id", r.status_code in (403, 404, 405), str(r.status_code))
        w = call("PATCH", f"/v1/{kind}/{rid}", owner_b, json={"name": "hijack"})
        check(f"B cannot change A's {kind}", w.status_code in (403, 404, 405), str(w.status_code))
    for kind in ("products", "suppliers", "cycles", "purchase-orders", "devices", "prosthetic-cases", "patients"):
        a_ids = {x["id"] for x in call("GET", f"/v1/{kind}?limit=100", owner_a).json().get("data", [])}
        b_ids = {x["id"] for x in call("GET", f"/v1/{kind}?limit=100", owner_b).json().get("data", [])}
        check(f"{kind}: A's and B's lists share no row", not (a_ids & b_ids), f"{len(a_ids)} vs {len(b_ids)}")
    # B cannot sign in to A, and A's token is useless against B's data
    bad = call("POST", "/v1/auth/login", json={"tenant_slug": slug, "email": f"owner-{slug_b}@example.com", "password": pw_b})
    check("B's credentials do not open practice A", bad.status_code in (401, 403, 422), str(bad.status_code))
    # B must not be able to attach A's patient or practitioner to its own case
    cross = call("POST", "/v1/prosthetic-cases", owner_b, json={
        "patient_id": patient_id, "practitioner_id": practitioner_id,
        "impression_type": "digital", "work_type": "crown", "impression_date": time.strftime("%Y-%m-%d"),
    })
    check("B cannot build a case from A's patient/practitioner", cross.status_code in (403, 404, 422), str(cross.status_code))

    print("== 3. permission changed mid-session")
    prac_token = tokens["practitioner"]
    before = call("POST", "/v1/patients", prac_token, json={})
    check("practitioner can create a patient before the change", before.status_code != 403, str(before.status_code))
    out = set_role(slug, emails["practitioner"], "viewer")
    check("practitioner demoted to viewer (set-up)", "ROLE_OK" in out, out[-80:])
    after = call("POST", "/v1/patients", prac_token, json={})
    check("the SAME token is refused right after the demotion", after.status_code == 403, str(after.status_code))
    read = call("GET", "/v1/prosthetic-cases", prac_token)
    check("...but it can still read what a viewer reads", read.status_code == 200, str(read.status_code))
    set_role(slug, emails["practitioner"], "practitioner")

    print()
    if FAILED:
        print(f"{len(FAILED)} check(s) FAILED:")
        for f in FAILED:
            print("  -", f)
        sys.exit(1)
    print("ALL PASS")


if __name__ == "__main__":
    main()
