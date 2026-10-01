#!/usr/bin/env python3
"""
Live proof of the Phase 3 "empty clinic" journey against the dev backend.

A brand-new practice with NO stock must be able to:
  1. register and sign in,
  2. list its storage locations (the mobile pickers) even though nothing is
     stored anywhere yet,
  3. order and receive its first delivery into one of those locations,
  4. then see the batch and the stock level.

Site and location creation is owned by the web app; this script stands in for
that single step with `artisan tinker` (dev stack only), exactly as an
administrator would do in the browser. Everything else goes through the same
public API the mobile app uses. Requires `pip install requests` and the dev
stack (docker compose up).

Usage: python scripts/verify_empty_clinic_journey.py
Creates one throwaway practice named zz-e2e-<random>.
"""
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


def main():
    slug = f"zz-e2e-{secrets.token_hex(3)}"
    password = "Zz-" + secrets.token_urlsafe(14)
    email = f"owner-{slug}@example.com"

    r = call("POST", "/v1/tenants", json={
        "tenant_name": "ZZ E2E Cabinet", "tenant_slug": slug,
        "owner_name": "Owner E2E", "owner_email": email, "password": password,
    })
    check("1. new practice registers", r.status_code in (200, 201), str(r.status_code))
    if r.status_code not in (200, 201):
        print(r.text[:300])
        sys.exit(1)

    r = call("POST", "/v1/auth/login", json={"tenant_slug": slug, "email": email, "password": password})
    check("2. owner signs in", r.status_code == 200, str(r.status_code))
    token = r.json()["token"]

    r = call("GET", "/v1/locations", token)
    check("3. empty clinic: locations endpoint answers", r.status_code == 200, str(r.status_code))
    before = len(r.json()["data"])
    r = call("GET", "/v1/batches", token)
    check("   no batches yet", r.status_code == 200 and r.json()["data"] == [])
    r = call("GET", "/v1/stock-levels", token)
    check("   no stock rows at all (the old workaround would offer nothing)", r.json()["data"] == [])

    # Web-owned step: an administrator creates the site and a location.
    php = (
        "$t=App\\Domain\\Tenancy\\Models\\Tenant::where('slug','%s')->first();"
        "App\\Support\\Tenancy\\TenantContext::run($t,function() use($t){"
        "$s=$t->sites()->firstOrCreate(['name'=>'Cabinet Principal']);"
        "$s->storageLocations()->create(['tenant_id'=>$t->id,'name'=>'Reserve']);});"
        "echo 'ok';" % slug
    )
    out = subprocess.run(
        ["docker", "exec", "steriqore-app", "php", "artisan", "tinker", "--execute=" + php],
        capture_output=True, text=True, timeout=120,
    )
    check("   (web step) site + location created", "ok" in out.stdout, out.stdout.strip()[-80:] + out.stderr.strip()[-80:])

    r = call("GET", "/v1/locations", token)
    locations = r.json()["data"]
    check("4. the new location is listed although it holds no stock",
          len(locations) == before + 1 and locations[-1]["name"] == "Reserve"
          and locations[-1]["site_name"] == "Cabinet Principal",
          str([(l["name"], l["site_name"]) for l in locations]))
    location_id = next(l["id"] for l in locations if l["name"] == "Reserve")

    supplier = call("POST", "/v1/suppliers", token, json={"name": "Fournisseur E2E"}).json()
    product = call("POST", "/v1/products", token, json={
        "name": "Gants nitrile", "reference": "GANT-E2E", "unit": "box", "min_threshold": 2,
    }).json()
    check("5. supplier and product created", "id" in supplier and "id" in product)

    po = call("POST", "/v1/purchase-orders", token, json={
        "supplier_id": supplier["id"],
        "lines": [{"product_id": product["id"], "qty_ordered": 10, "unit_price": 4.5}],
    }).json()
    check("6. purchase order created", "id" in po, str(po)[:120])
    placed = call("POST", f"/v1/purchase-orders/{po['id']}/order", token)
    check("   order placed", placed.status_code in (200, 201), str(placed.status_code))

    line_id = call("GET", f"/v1/purchase-orders/{po['id']}", token).json()["lines"][0]["id"]
    receipt = call("POST", f"/v1/purchase-orders/{po['id']}/receipts", token, json={
        "location_id": location_id,
        "lines": [{
            "purchase_order_line_id": line_id, "batch_number": "LOT-E2E-1",
            "expiry_date": "2028-12-31", "qty": 6,
        }],
    })
    check("7. FIRST DELIVERY received into the new location (partial: 6 of 10)",
          receipt.status_code in (200, 201), str(receipt.status_code) + " " + receipt.text[:120])

    batches = call("GET", "/v1/batches", token).json()["data"]
    check("8. the batch is listed with its quantity on hand",
          len(batches) == 1 and batches[0]["batch_number"] == "LOT-E2E-1" and batches[0]["qty_on_hand"] == 6,
          str([(b["batch_number"], b["qty_on_hand"]) for b in batches]))
    levels = call("GET", "/v1/stock-levels", token).json()["data"]
    check("9. stock level shows 6 in that location",
          len(levels) == 1 and levels[0]["quantity"] == 6 and levels[0]["location_id"] == location_id)

    practitioners = call("GET", "/v1/practitioners", token).json()["data"]
    check("10. the practitioner picker lists the owner (name only)",
          len(practitioners) == 1 and set(practitioners[0].keys()) == {"id", "name", "role"},
          str(practitioners))

    print()
    print("EMPTY-CLINIC JOURNEY: " + ("PASS" if not FAILED else f"FAIL ({len(FAILED)}): {FAILED}"))
    print(f"(throwaway practice slug: {slug})")
    sys.exit(0 if not FAILED else 1)


if __name__ == "__main__":
    main()
