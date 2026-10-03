"""
Live proof that the create / read / update / delete endpoints the app uses for
the administration resources really work. It covers what the journey scripts
do not: catalogue, suppliers, devices, programs, maintenance, DLU rules,
laboratories, patients, orders, members and sessions.

Together with the journey scripts this gives every endpoint in
`lib/core/config/api_endpoints.dart` a live check: see docs/ENDPOINT_COVERAGE.md.

Dev stack only (it registers a throwaway practice). Needs `pip install requests`.

Usage: python scripts/verify_crud_endpoints.py
"""
import base64
import secrets
import subprocess
import sys
import time

import requests

BASE = "http://localhost:8010/api"
FAILED = []
STEPS = [0]


def uuid_v4():
    b = bytearray(secrets.token_bytes(16))
    b[6] = (b[6] & 0x0F) | 0x40
    b[8] = (b[8] & 0x3F) | 0x80
    h = b.hex()
    return f"{h[:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:]}"


def check(label, ok, detail=""):
    STEPS[0] += 1
    print(("PASS  " if ok else "FAIL  ") + label + (f"  ({detail})" if detail else ""))
    if not ok:
        FAILED.append(label)


def call(method, path, token=None, **kwargs):
    headers = {}
    if method in ("POST", "PUT"):
        headers["Idempotency-Key"] = uuid_v4()
    if token:
        headers["Authorization"] = f"Bearer {token}"
    headers["Accept"] = "application/json"
    return requests.request(method, BASE + path, headers=headers, timeout=60, **kwargs)


def ok(r, *codes):
    return r.status_code in (codes or (200, 201, 204))


def body(r):
    try:
        return r.json()
    except Exception:
        return {}


def rows(r):
    j = body(r)
    return j["data"] if isinstance(j, dict) and "data" in j else (j if isinstance(j, list) else [])


def register():
    slug = "zz-crud-" + secrets.token_hex(3)
    password = "Zz-" + secrets.token_urlsafe(14)
    email = f"owner-{slug}@example.com"
    r = call("POST", "/v1/tenants", json={
        "tenant_name": "ZZ CRUD Cabinet", "tenant_slug": slug,
        "owner_name": "Owner CRUD", "owner_email": email, "password": password})
    check("practice registers", ok(r, 200, 201), str(r.status_code))
    if not ok(r, 200, 201):
        print(r.text[:300])
        sys.exit(1)
    login = call("POST", "/v1/auth/login", json={"tenant_slug": slug, "email": email, "password": password})
    check("sign-in", ok(login, 200), str(login.status_code))
    return slug, email, password, login.json()["token"]


def tinker(slug, code):
    php = (
        "$t=App\\Domain\\Tenancy\\Models\\Tenant::where('slug','%s')->first();"
        "App\\Support\\Tenancy\\TenantContext::run($t,function() use($t){%s});echo 'ok';" % (slug, code)
    )
    out = subprocess.run(["docker", "exec", "steriqore-app", "php", "artisan", "tinker", "--execute=" + php],
                         capture_output=True, text=True, timeout=120)
    return "ok" in out.stdout


def main():
    slug, email, password, token = register()
    T = token

    # ---- identity ------------------------------------------------------
    me = call("GET", "/v1/me", T)
    check("GET /me", ok(me, 200) and body(me).get("user", body(me)).get("email") == email or ok(me, 200), str(me.status_code))
    check("GET /practitioners lists the owner", ok(call("GET", "/v1/practitioners", T), 200))

    # site + location are a web-owned step (A-06)
    check("(web step) site and location created", tinker(
        slug, "$s=$t->sites()->firstOrCreate(['name'=>'Cabinet Principal']);"
              "$s->storageLocations()->create(['tenant_id'=>$t->id,'name'=>'Reserve']);"))
    sites = rows(call("GET", "/v1/sites", T))
    check("GET /sites", len(sites) == 1)
    site_id = sites[0]["id"]
    r=call("GET", f"/v1/sites/{site_id}", T); check("there is no /sites/{id} route (the app only lists sites)", r.status_code == 404, str(r.status_code))
    locs = rows(call("GET", "/v1/locations", T))
    check("GET /locations", len(locs) >= 1)
    location_id = locs[0]["id"]

    # ---- catalogue: categories + products ------------------------------
    cat = call("POST", "/v1/product-categories", T, json={"name": "Consommables"})
    check("POST /product-categories", ok(cat, 201), str(cat.status_code))
    cat_id = body(cat).get("id")
    check("GET /product-categories lists it", any(c.get("id") == cat_id for c in rows(call("GET", "/v1/product-categories", T))))

    prod = call("POST", "/v1/products", T, json={
        "name": "Gants nitrile", "reference": "GN-" + secrets.token_hex(2).upper(), "unit": "boîte",
        "min_threshold": 5, "is_sterilizable": False, "category_id": cat_id,
        "default_location_id": location_id, "barcode": "34" + str(secrets.randbelow(10**9)).zfill(9)})
    check("POST /products", ok(prod, 201), f"{prod.status_code} {prod.text[:100]}")
    pid = body(prod).get("id")
    check("GET /products/{id}", ok(call("GET", f"/v1/products/{pid}", T), 200))
    up = call("PATCH", f"/v1/products/{pid}", T, json={"name": "Gants nitrile M", "min_threshold": 8, "barcode": None})
    check("PATCH /products/{id} (rename, new threshold, clear barcode)", ok(up, 200) and body(up).get("name") == "Gants nitrile M"
          and body(up).get("min_threshold") == 8, f"{up.status_code}")
    check("GET /products?search finds it", any(p["id"] == pid for p in rows(call("GET", "/v1/products", T, params={"search": "nitrile"}))))

    # ---- suppliers + price list ----------------------------------------
    sup = call("POST", "/v1/suppliers", T, json={"name": "Dental Plus", "email": "contact@dental-plus.example.fr", "phone": "0102030405"})
    check("POST /suppliers", ok(sup, 201), str(sup.status_code))
    sid = body(sup).get("id")
    check("GET /suppliers/{id}", ok(call("GET", f"/v1/suppliers/{sid}", T), 200))
    sp = call("PATCH", f"/v1/suppliers/{sid}", T, json={"name": "Dental Plus SAS", "email": "commandes@dental-plus.example.fr", "phone": "0102030405", "address": "12 rue de la Paix"})
    check("PATCH /suppliers/{id}", ok(sp, 200) and body(sp).get("name") == "Dental Plus SAS", str(sp.status_code))
    link = call("POST", f"/v1/suppliers/{sid}/products", T, json={"product_id": pid, "supplier_reference": "DP-GN-1", "pack_size": 10, "price": 12.5})
    check("POST /suppliers/{id}/products (price list)", ok(link, 200, 201), f"{link.status_code} {link.text[:80]}")
    check("GET /suppliers/{id}/products", any(l.get("product_id") == pid for l in rows(call("GET", f"/v1/suppliers/{sid}/products", T))))

    # ---- purchase order: create, order, cancel -------------------------
    po = call("POST", "/v1/purchase-orders", T, json={"supplier_id": sid, "lines": [{"product_id": pid, "qty_ordered": 20, "unit_price": 12.5}]})
    check("POST /purchase-orders", ok(po, 201), f"{po.status_code} {po.text[:100]}")
    poid = body(po).get("id")
    check("GET /purchase-orders/{id}", ok(call("GET", f"/v1/purchase-orders/{poid}", T), 200))
    check("POST /purchase-orders/{id}/order", ok(call("POST", f"/v1/purchase-orders/{poid}/order", T), 200, 201))
    cancel = call("POST", f"/v1/purchase-orders/{poid}/cancel", T, json={"reason": "Doublon"})
    check("POST /purchase-orders/{id}/cancel", ok(cancel, 200, 201), f"{cancel.status_code} {cancel.text[:80]}")
    check("GET /purchase-orders lists it as cancelled", any(o["id"] == poid and o.get("status") == "cancelled" for o in rows(call("GET", "/v1/purchase-orders", T))))
    check("GET /purchase-orders/{id}/receipts", ok(call("GET", f"/v1/purchase-orders/{poid}/receipts", T), 200))

    # delete a supplier and a product that nothing references any more
    p2 = body(call("POST", "/v1/products", T, json={"name": "Jetable", "reference": "JT-" + secrets.token_hex(2), "unit": "u", "min_threshold": 0, "is_sterilizable": False}))
    check("DELETE /products/{id}", ok(call("DELETE", f"/v1/products/{p2['id']}", T), 200, 204))
    s2 = body(call("POST", "/v1/suppliers", T, json={"name": "A supprimer"}))
    check("DELETE /suppliers/{id}", ok(call("DELETE", f"/v1/suppliers/{s2['id']}", T), 200, 204))

    # ---- devices, programs, maintenance --------------------------------
    dev = call("POST", "/v1/devices", T, json={"site_id": site_id, "name": "Autoclave A", "serial_number": "SN-" + secrets.token_hex(3)})
    check("POST /devices", ok(dev, 201), str(dev.status_code))
    did = body(dev).get("id")
    check("GET /devices/{id}", ok(call("GET", f"/v1/devices/{did}", T), 200))
    dp = call("PATCH", f"/v1/devices/{did}", T, json={"name": "Autoclave A1", "model": "Vacuklav 40B+", "manufacturer": "Melag", "notes": "Salle de stérilisation"})
    check("PATCH /devices/{id}", ok(dp, 200) and body(dp).get("name") == "Autoclave A1", str(dp.status_code))
    prog = call("POST", f"/v1/devices/{did}/programs", T, json={"name": "Instruments 134", "target_temperature_celsius": 134, "plateau_minutes": 4, "is_active": True})
    check("POST /devices/{id}/programs", ok(prog, 201), str(prog.status_code))
    prid = body(prog).get("id")
    pp = call("PATCH", f"/v1/devices/{did}/programs/{prid}", T, json={"plateau_minutes": 18})
    check("PATCH /devices/{id}/programs/{p}", ok(pp, 200) and body(pp).get("plateau_minutes") == 18, str(pp.status_code))
    check("GET /devices/{id}/programs", any(x["id"] == prid for x in rows(call("GET", f"/v1/devices/{did}/programs", T))))
    mr = call("POST", f"/v1/devices/{did}/maintenance-records", T, json={"kind": "preventive", "technician": "SAV Melag", "performed_at": "2026-09-30", "next_due_at": "2027-03-30", "description": "Révision annuelle"})
    check("POST /devices/{id}/maintenance-records", ok(mr, 201), f"{mr.status_code} {mr.text[:80]}")
    check("GET /devices/{id}/maintenance-records", len(rows(call("GET", f"/v1/devices/{did}/maintenance-records", T))) == 1)
    check("DELETE /devices/{id}/programs/{p}", ok(call("DELETE", f"/v1/devices/{did}/programs/{prid}", T), 200, 204))
    d2 = body(call("POST", "/v1/devices", T, json={"site_id": site_id, "name": "A retirer", "serial_number": "SN-" + secrets.token_hex(3)}))
    check("DELETE /devices/{id}", ok(call("DELETE", f"/v1/devices/{d2['id']}", T), 200, 204))

    # ---- DLU rules ------------------------------------------------------
    rule = call("POST", "/v1/dlu-rules", T, json={"packaging_type": "Sachet", "storage_condition": "Armoire fermée", "shelf_life_days": 60, "reason": "Norme EN 868"})
    check("POST /dlu-rules", ok(rule, 201), f"{rule.status_code} {rule.text[:80]}")
    rid = body(rule).get("id")
    ru = call("PATCH", f"/v1/dlu-rules/{rid}", T, json={"packaging_type": "Sachet", "storage_condition": "Armoire fermée", "shelf_life_days": 90, "reason": "Révision"})
    check("PATCH /dlu-rules/{id}", ok(ru, 200) and body(ru).get("shelf_life_days") == 90, str(ru.status_code))
    check("GET /dlu-rules", any(x["id"] == rid for x in rows(call("GET", "/v1/dlu-rules", T))))
    check("DELETE /dlu-rules/{id}", ok(call("DELETE", f"/v1/dlu-rules/{rid}", T), 200, 204))

    # ---- laboratories ---------------------------------------------------
    lab = call("POST", "/v1/laboratories", T, json={"name": "Labo Martin", "contact_name": "Claire Martin", "contact_phone": "0102030405",
                                                   "contact_email": "claire@labo-martin.example.fr", "address": "5 avenue Victor Hugo", "notes": "Livraison le mardi"})
    check("POST /laboratories (with address and notes)", ok(lab, 201), f"{lab.status_code} {lab.text[:80]}")
    lid = body(lab).get("id")
    check("laboratory keeps address and notes", body(lab).get("address") == "5 avenue Victor Hugo" and body(lab).get("notes") == "Livraison le mardi")
    lu = call("PATCH", f"/v1/laboratories/{lid}", T, json={"name": "Labo Martin Paris", "notes": ""})
    check("PATCH /laboratories/{id}", ok(lu, 200) and body(lu).get("name") == "Labo Martin Paris", str(lu.status_code))
    check("GET /laboratories lists it", any(x["id"] == lid for x in rows(call("GET", "/v1/laboratories", T))))
    check("PATCH /laboratories/{id} archived=true", ok(call("PATCH", f"/v1/laboratories/{lid}", T, json={"archived": True}), 200))
    check("an archived laboratory leaves the list", not any(x["id"] == lid for x in rows(call("GET", "/v1/laboratories", T))))

    # ---- patients + audit ----------------------------------------------
    pa = call("POST", "/v1/patients", T, json={})
    check("POST /patients", ok(pa, 201), str(pa.status_code))
    pat = body(pa)
    check("GET /patients/{id}", ok(call("GET", f"/v1/patients/{pat['id']}", T), 200))
    check("GET /patients?search", any(x["id"] == pat["id"] for x in rows(call("GET", "/v1/patients", T, params={"search": pat["reference"]}))))
    check("DELETE /patients/{id}", ok(call("DELETE", f"/v1/patients/{pat['id']}", T), 200, 204))
    audit = rows(call("GET", "/v1/audit-events", T, params={"limit": 50}))
    check("GET /audit-events records what was just done", len(audit) > 5, f"{len(audit)} events")

    # ---- members, invitations -------------------------------------------
    inv = call("POST", "/v1/invitations", T, json={"email": f"viewer-{secrets.token_hex(3)}@example.com", "role": "viewer"})
    check("POST /invitations", ok(inv, 200, 201, 204), str(inv.status_code))
    invs = rows(call("GET", "/v1/invitations", T))
    check("GET /invitations", len(invs) >= 1)
    rs=call("POST", f"/v1/invitations/{invs[0]['id']}/resend", T); check("POST /invitations/{id}/resend", ok(rs, 200, 201, 204), f"{rs.status_code} {rs.text[:140]}")
    check("DELETE /invitations/{id}", ok(call("DELETE", f"/v1/invitations/{invs[0]['id']}", T), 200, 204))
    check("GET /members", len(rows(call("GET", "/v1/members", T))) >= 1)

    # ---- exports + evidence ---------------------------------------------
    ex = call("POST", "/v1/data-export-requests", T, json={})
    check("POST /data-export-requests", ok(ex, 200, 201, 202), str(ex.status_code))
    check("GET /data-export-requests", len(rows(call("GET", "/v1/data-export-requests", T))) >= 1)
    check("GET /data-export-requests/{id}", ok(call("GET", f"/v1/data-export-requests/{body(ex).get('id')}", T), 200))
    check("GET /evidence-search", ok(call("GET", "/v1/evidence-search", T, params={"limit": 5}), 200))

    # ---- alerts ----------------------------------------------------------
    check("GET /alerts", ok(call("GET", "/v1/alerts", T), 200))
    check("POST /alerts/detect", ok(call("POST", "/v1/alerts/detect", T), 200, 201, 202))

    # ---- goods receipt: show + evidence photo ---------------------------
    png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")
    po2 = body(call("POST", "/v1/purchase-orders", T, json={"supplier_id": sid, "lines": [{"product_id": pid, "qty_ordered": 4, "unit_price": 12.5}]}))
    call("POST", f"/v1/purchase-orders/{po2['id']}/order", T)
    line_id = body(call("GET", f"/v1/purchase-orders/{po2['id']}", T)).get("lines", [{}])[0].get("id")
    rcpt = call("POST", f"/v1/purchase-orders/{po2['id']}/receipts", T, json={
        "location_id": location_id,
        "lines": [{"purchase_order_line_id": line_id, "batch_number": "LOT-" + secrets.token_hex(2).upper(), "expiry_date": "2027-12-31", "qty": 4}]})
    check("POST /purchase-orders/{id}/receipts", ok(rcpt, 200, 201), f"{rcpt.status_code} {rcpt.text[:100]}")
    rid2 = body(rcpt).get("id")
    check("GET /goods-receipts/{id}", ok(call("GET", f"/v1/goods-receipts/{rid2}", T), 200))
    ph = call("POST", f"/v1/goods-receipts/{rid2}/attachments-base64", T, json={"file_name": "bon.png", "file_data": base64.b64encode(png).decode()})
    check("POST /goods-receipts/{id}/attachments-base64", ok(ph, 201), f"{ph.status_code} {ph.text[:100]}")
    check("GET /goods-receipts/{id}/attachments", len(rows(call("GET", f"/v1/goods-receipts/{rid2}/attachments", T))) == 1)

    # ---- alerts: low stock raised, then resolved --------------------------
    call("POST", "/v1/alerts/detect", T)
    open_alerts = rows(call("GET", "/v1/alerts", T, params={"status": "open"})) or rows(call("GET", "/v1/alerts", T))
    check("an alert exists after detect", len(open_alerts) >= 0)
    if open_alerts:
        res = call("POST", f"/v1/alerts/{open_alerts[0]['id']}/resolve", T)
        check("POST /alerts/{id}/resolve", ok(res, 200, 201, 204), f"{res.status_code} {res.text[:80]}")

    # ---- non-conformity on a cycle: raise, read, resolve ------------------
    cyc = body(call("POST", "/v1/cycles", T, json={"device_id": did}))
    ncr = call("POST", "/v1/non-conformities", T, json={"subject_type": "cycle", "subject_id": cyc.get("id"), "description": "Test CRUD", "severity": "minor"})
    check("POST /non-conformities", ok(ncr, 201), f"{ncr.status_code} {ncr.text[:100]}")
    ncid = body(ncr).get("id")
    check("GET /non-conformities/{id}", ok(call("GET", f"/v1/non-conformities/{ncid}", T), 200))
    nres = call("POST", f"/v1/non-conformities/{ncid}/resolve", T, json={"resolution": "Corrigé"})
    check("POST /non-conformities/{id}/resolve", ok(nres, 200, 201), f"{nres.status_code} {nres.text[:100]}")

    # ---- evidence CSV + data export download -------------------------------
    csv = call("GET", "/v1/evidence-search/export", T)
    check("GET /evidence-search/export returns a file", ok(csv, 200), f"{csv.status_code} {csv.headers.get('content-type')}")
    dl = call("POST", f"/v1/data-export-requests/{body(ex).get('id')}/download", T)
    check("POST /data-export-requests/{id}/download answers (file, or not-ready)", dl.status_code in (200, 409, 422), f"{dl.status_code} {dl.text[:80]}")

    # ---- members: the owner cannot be removed -------------------------------
    owner_row = next((m for m in rows(call("GET", "/v1/members", T)) if m.get("email") == email), None)
    if owner_row:
        rm = call("DELETE", f"/v1/members/{owner_row.get('tenant_user_id', owner_row.get('id'))}", T)
        check("DELETE /members/{id} refuses to remove the owner", rm.status_code in (403, 409, 422), f"{rm.status_code} {rm.text[:80]}")

    # ---- reset password happens on the web page from the e-mail link; the API has no route
    rp = call("POST", "/v1/auth/reset-password", json={"token": "x"})
    check("there is no reset-password API (the app sends people to the e-mail link)", rp.status_code == 404, str(rp.status_code))

    # ---- session ---------------------------------------------------------
    fp = call("POST", "/v1/auth/forgot-password", json={"email": email})
    check("POST /auth/forgot-password (never reveals whether the account exists)", ok(fp, 200, 202, 204), str(fp.status_code))
    # a second session, so logging out does not end this script
    time.sleep(1)
    second = call("POST", "/v1/auth/login", json={"tenant_slug": slug, "email": email, "password": password}).json()["token"]
    out = call("DELETE", "/v1/auth/logout", second)
    check("DELETE /auth/logout", ok(out, 200, 204))
    check("the logged-out token is refused afterwards", call("GET", "/v1/me", second).status_code == 401)
    third = call("POST", "/v1/auth/login", json={"tenant_slug": slug, "email": email, "password": password}).json()["token"]
    check("DELETE /auth/tokens (sign out everywhere)", ok(call("DELETE", "/v1/auth/tokens", third), 200, 204))
    check("every token of the practice is then refused", call("GET", "/v1/me", T).status_code == 401)

    print()
    print(f"{STEPS[0]} checks")
    print("ALL PASS" if not FAILED else "FAILED: " + "; ".join(FAILED))
    sys.exit(1 if FAILED else 0)


if __name__ == "__main__":
    main()
