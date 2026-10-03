#!/usr/bin/env python3
"""
Live proof of the Phase 5 stock chain against the dev backend (the API half of
journey J-STOCK; camera scanning and the photo picker are device steps, see
docs/DEVICE_TEST_LOG.md).

Proves, with server read-back after every step:
  empty clinic -> supplier, product, order -> partial receipt (lot + expiry
  from the user) -> remainder -> product code lookup (barcode, reference, lot,
  unknown) -> issue / transfer / adjust -> a replayed key moves stock ONCE and
  a tampered replay is refused -> inventory count: open, duplicate refused,
  count lines, close refused while stock is uncounted, close with the explicit
  acknowledgement writes exactly the variance, a viewer can read but not write.

Locations and the read-only member are set up with `artisan tinker` (dev stack
only), standing in for web/admin actions. Requires `pip install requests` and
the dev stack. Creates one throwaway practice named zz-e2e-<random>.

Usage: python scripts/verify_stock_journey.py
"""
import re
import secrets
import subprocess
import sys
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
    headers = {}
    if method in ("POST", "PUT", "PATCH", "DELETE"):
        headers["Idempotency-Key"] = key or uuid_v4()
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


def level(token, batch_id, location_id):
    rows = call("GET", "/v1/stock-levels?limit=200", token).json()["data"]
    for row in rows:
        if row.get("batch_id") == batch_id and row.get("location_id") == location_id:
            return row["quantity"]
    return 0


def main():
    slug = f"zz-e2e-{secrets.token_hex(3)}"
    password = "Zz-" + secrets.token_urlsafe(14)
    email = f"owner-{slug}@example.com"
    viewer_email = f"viewer-{slug}@example.com"

    r = call("POST", "/v1/tenants", json={
        "tenant_name": "ZZ E2E Stock", "tenant_slug": slug,
        "owner_name": "Owner E2E", "owner_email": email, "password": password,
    })
    check("1. practice registers", r.status_code in (200, 201), str(r.status_code))
    if r.status_code not in (200, 201):
        print(r.text[:300])
        sys.exit(1)
    login = call("POST", "/v1/auth/login", json={"tenant_slug": slug, "email": email, "password": password})
    token = login.json()["token"]
    check("2. owner signs in", login.status_code == 200)

    # Empty clinic: no locations yet. The web owns creating them.
    empty = call("GET", "/v1/locations", token).json()["data"]
    check("3. a brand-new clinic starts with no location", len(empty) == 0, str(len(empty)))

    out = tinker(
        "$t=App\\Domain\\Tenancy\\Models\\Tenant::where('slug','%s')->first();"
        "App\\Support\\Tenancy\\TenantContext::run($t,function() use($t){"
        "$s=$t->sites()->firstOrCreate(['name'=>'Cabinet Principal']);"
        "$a=App\\Domain\\Tenancy\\Models\\StorageLocation::create(['tenant_id'=>$t->id,'site_id'=>$s->id,'name'=>'Reserve']);"
        "$b=App\\Domain\\Tenancy\\Models\\StorageLocation::create(['tenant_id'=>$t->id,'site_id'=>$s->id,'name'=>'Bloc']);"
        "$u=App\\Models\\User::create(['name'=>'Viewer E2E','email'=>'%s','password'=>Illuminate\\Support\\Facades\\Hash::make('%s')]);"
        "App\\Domain\\Identity\\Models\\TenantUser::create(['tenant_id'=>$t->id,'user_id'=>$u->id,'status'=>'active']);"
        "$r=app(Spatie\\Permission\\PermissionRegistrar::class);$r->setPermissionsTeamId($t->id);"
        "$u->assignRole('viewer');echo 'LOCS='.$a->id.','.$b->id;});"
        % (slug, viewer_email, password)
    )
    m = re.search(r"LOCS=([0-9a-f-]{36}),([0-9a-f-]{36})", out)
    check("4. (web step) two locations + viewer member created", bool(m), out[-160:])
    if not m:
        sys.exit(1)
    reserve, bloc = m.group(1), m.group(2)
    v = call("POST", "/v1/auth/login", json={"tenant_slug": slug, "email": viewer_email, "password": password})
    viewer = v.json().get("token")
    check("   viewer signs in", v.status_code == 200 and viewer)

    # ---- catalogue, supplier, order
    barcode = "3401" + secrets.token_hex(3)
    product = call("POST", "/v1/products", token, json={
        "name": "Gants nitrile", "reference": "GN-" + secrets.token_hex(2),
        "unit": "boite", "min_threshold": 2, "barcode": barcode,
    }).json()
    pid = product.get("id")
    check("5. product created", bool(pid), str(product)[:100])
    supplier = call("POST", "/v1/suppliers", token, json={"name": "Dental Plus"}).json()
    sid = supplier.get("id")
    check("   supplier created", bool(sid), str(supplier)[:100])
    po = call("POST", "/v1/purchase-orders", token, json={
        "supplier_id": sid, "lines": [{"product_id": pid, "qty_ordered": 10, "unit_price": 4.5}],
    })
    check("6. order drafted", po.status_code in (200, 201), str(po.status_code) + po.text[:120])
    po = po.json()
    line_id = po["lines"][0]["id"]
    o = call("POST", f"/v1/purchase-orders/{po['id']}/order", token)
    check("   order placed", o.status_code in (200, 201), str(o.status_code))

    # ---- partial receipt with a manufacturer lot + expiry from the user
    lot = "LOT-" + secrets.token_hex(2).upper()
    expiry = (date.today() + timedelta(days=200)).isoformat()
    rec1 = call("POST", f"/v1/purchase-orders/{po['id']}/receipts", token, json={
        "location_id": reserve,
        "lines": [{"purchase_order_line_id": line_id, "batch_number": lot, "expiry_date": expiry, "qty": 6}],
    })
    check("7. partial receipt (6 of 10)", rec1.status_code in (200, 201), str(rec1.status_code) + rec1.text[:150])
    over = call("POST", f"/v1/purchase-orders/{po['id']}/receipts", token, json={
        "location_id": reserve,
        "lines": [{"purchase_order_line_id": line_id, "batch_number": lot, "expiry_date": expiry, "qty": 5}],
    })
    check("   receiving more than remains is refused", over.status_code == 422 or err_code(over) == "RECEIPT_EXCEEDS_ORDERED",
          err_code(over))
    rec2 = call("POST", f"/v1/purchase-orders/{po['id']}/receipts", token, json={
        "location_id": reserve,
        "lines": [{"purchase_order_line_id": line_id, "batch_number": lot, "expiry_date": expiry, "qty": 4}],
    })
    check("8. remainder received (4)", rec2.status_code in (200, 201), str(rec2.status_code))
    receipts = call("GET", f"/v1/purchase-orders/{po['id']}/receipts", token)
    check("   receipt history lists both receipts",
          receipts.status_code == 200 and len(receipts.json()) == 2,
          str(receipts.status_code))

    # ---- code lookup (pure read)
    by_bar = call("GET", "/v1/lookups/code", token, params={"code": barcode})
    check("9. lookup by barcode", by_bar.status_code == 200 and by_bar.json()["matched_by"] == "barcode", str(by_bar.status_code))
    batch = by_bar.json()["products"][0]["batches"][0]
    batch_id = batch["id"]
    check("   lot, expiry and location quantity are returned",
          batch["batch_number"] == lot and batch["qty_on_hand"] == 10
          and batch["locations"][0]["quantity"] == 10, str(batch)[:140])
    by_lot = call("GET", "/v1/lookups/code", token, params={"code": lot})
    check("   lookup by lot number", by_lot.status_code == 200 and by_lot.json()["matched_by"] == "batch_number")
    by_ref = call("GET", "/v1/lookups/code", token, params={"code": product["reference"]})
    check("   lookup by reference", by_ref.status_code == 200 and by_ref.json()["matched_by"] == "reference")
    unknown = call("GET", "/v1/lookups/code", token, params={"code": "NOPE-" + secrets.token_hex(3)})
    check("   unknown code -> 404 CODE_NOT_FOUND", unknown.status_code == 404 and err_code(unknown) == "CODE_NOT_FOUND", err_code(unknown))
    check("   a lookup changed nothing", level(token, batch_id, reserve) == 10)

    # ---- movements, with a replayed key
    key = uuid_v4()
    payload = {"batch_id": batch_id, "location_id": reserve, "qty": 3}
    i1 = call("POST", "/v1/stock-movements/issue", token, key=key, json=payload)
    check("10. issue 3", i1.status_code in (200, 201), str(i1.status_code))
    i2 = call("POST", "/v1/stock-movements/issue", token, key=key, json=payload)
    check("   same key replayed (lost response) -> same movement, not a second one",
          i2.status_code in (200, 201) and i2.json().get("id") == i1.json().get("id"), str(i2.status_code))
    check("   server read-back: 7 left, not 4", level(token, batch_id, reserve) == 7, str(level(token, batch_id, reserve)))
    i3 = call("POST", "/v1/stock-movements/issue", token, key=key, json={**payload, "qty": 1})
    check("   same key, different body -> refused", i3.status_code == 409, str(i3.status_code))
    tooMuch = call("POST", "/v1/stock-movements/issue", token, json={**payload, "qty": 99})
    check("   issuing more than is there is refused", tooMuch.status_code in (409, 422), str(tooMuch.status_code))
    t = call("POST", "/v1/stock-movements/transfer", token, json={
        "batch_id": batch_id, "from_location_id": reserve, "to_location_id": bloc, "qty": 2})
    check("11. transfer 2 Reserve -> Bloc", t.status_code in (200, 201), str(t.status_code))
    check("   read-back: Reserve 5, Bloc 2", level(token, batch_id, reserve) == 5 and level(token, batch_id, bloc) == 2)
    a = call("POST", "/v1/stock-movements/adjust", token, json={
        "batch_id": batch_id, "location_id": reserve, "qty": -1, "reason": "casse"})
    check("12. adjust -1 with a reason", a.status_code in (200, 201), str(a.status_code))
    noReason = call("POST", "/v1/stock-movements/adjust", token, json={
        "batch_id": batch_id, "location_id": reserve, "qty": -1})
    check("   adjust without a reason is refused", noReason.status_code == 422, str(noReason.status_code))
    check("   read-back: Reserve 4", level(token, batch_id, reserve) == 4)

    # ---- inventory count
    c = call("POST", "/v1/inventory-counts", token, json={"location_id": reserve, "note": "Controle mensuel"})
    check("13. inventory opened on Reserve", c.status_code == 201, str(c.status_code) + c.text[:150])
    count = c.json()
    cid = count["summary"]["id"]
    check("   the lot is listed as still to count (system 4)",
          [u["system_qty"] for u in count["uncounted"]] == [4], str(count["uncounted"])[:120])
    dup = call("POST", "/v1/inventory-counts", token, json={"location_id": reserve})
    check("   a second open count on the same place is refused",
          dup.status_code == 409 and err_code(dup) == "INVENTORY_COUNT_ALREADY_OPEN", err_code(dup))

    vlist = call("GET", "/v1/inventory-counts", viewer)
    check("   viewer can read counts", vlist.status_code == 200, str(vlist.status_code))
    vopen = call("POST", "/v1/inventory-counts", viewer, json={"location_id": bloc})
    check("   viewer cannot open one", vopen.status_code == 403, str(vopen.status_code))
    vline = call("PUT", f"/v1/inventory-counts/{cid}/lines/{batch_id}", viewer, json={"counted_qty": 1})
    check("   viewer cannot count", vline.status_code == 403, str(vline.status_code))

    early = call("POST", f"/v1/inventory-counts/{cid}/close", token, json={"acknowledge_uncounted": False})
    check("   closing before counting is refused (uncounted stock)",
          early.status_code == 409 and err_code(early) == "INVENTORY_COUNT_UNCOUNTED_STOCK", err_code(early))
    bad = call("PUT", f"/v1/inventory-counts/{cid}/lines/{batch_id}", token, json={"counted_qty": -1})
    check("   a negative count is refused", bad.status_code == 422, str(bad.status_code))
    line = call("PUT", f"/v1/inventory-counts/{cid}/lines/{batch_id}", token, json={"counted_qty": 3})
    check("14. counted 3 (system said 4) -> variance -1",
          line.status_code == 200 and line.json()["variance"] == -1 and line.json()["expected_qty"] == 4,
          str(line.status_code) + line.text[:120])
    shown = call("GET", f"/v1/inventory-counts/{cid}", token).json()
    check("   server read-back: one line, nothing left to count",
          len(shown["lines"]) == 1 and shown["uncounted"] == [])
    check("   counting alone does not touch stock", level(token, batch_id, reserve) == 4)
    done = call("POST", f"/v1/inventory-counts/{cid}/close", token, json={"acknowledge_uncounted": False})
    check("15. close writes the adjustment", done.status_code == 201 and done.json()["summary"]["status"] == "closed"
          and done.json()["summary"]["adjustments_count"] == 1, str(done.status_code))
    check("   read-back: Reserve is now 3", level(token, batch_id, reserve) == 3, str(level(token, batch_id, reserve)))
    again = call("POST", f"/v1/inventory-counts/{cid}/close", token, json={"acknowledge_uncounted": True})
    check("   closing twice is refused, no second adjustment",
          again.status_code == 409 and err_code(again) == "INVENTORY_COUNT_NOT_OPEN" and level(token, batch_id, reserve) == 3,
          err_code(again))

    # ---- cancel path
    c2 = call("POST", "/v1/inventory-counts", token, json={"location_id": bloc}).json()
    noWhy = call("POST", f"/v1/inventory-counts/{c2['summary']['id']}/cancel", token, json={})
    check("16. cancelling needs a reason", noWhy.status_code == 422, str(noWhy.status_code))
    cx = call("POST", f"/v1/inventory-counts/{c2['summary']['id']}/cancel", token, json={"reason": "Mauvais emplacement"})
    check("   cancelled with a reason, stock untouched",
          cx.status_code == 201 and cx.json()["summary"]["status"] == "cancelled" and level(token, batch_id, bloc) == 2,
          str(cx.status_code))
    lst = call("GET", "/v1/inventory-counts", token, params={"filter[status]": "closed"}).json()["data"]
    check("   list filters by status", len(lst) == 1 and lst[0]["status"] == "closed", str(len(lst)))

    print()
    if FAILED:
        print(f"{len(FAILED)} FAILED:")
        for f in FAILED:
            print("  - " + f)
        sys.exit(1)
    print("ALL PASS")


if __name__ == "__main__":
    main()
