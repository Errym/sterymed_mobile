#!/usr/bin/env python3
"""
Seeds one throwaway practice on the DEV backend for the Chrome journeys in
integration_test/journeys/ and writes build/web-journeys/defines.json for
`flutter drive --dart-define-from-file`.

The practice (zz-web-<random>) gets one user per backend role, a site with two
locations, a device + programme, a supplier, two products, one ordered but not
yet received purchase order, one product with received stock (lot + expiry), a
released cycle with printed labels (one fresh, one to be used), a patient and a
prosthetic laboratory with a case. Web-owned steps (site, locations, extra
members) use `artisan tinker`, dev stack only.

Usage: python scripts/seed_web_journeys.py
"""
import base64
import json
import re
import secrets
import subprocess
import sys
from datetime import date, timedelta
from pathlib import Path

import requests

BASE = "http://localhost:8010/api"
OUT = Path(__file__).resolve().parents[1] / "build" / "web-journeys"
ROLES = ["admin", "stock_manager", "releaser", "practitioner", "viewer"]


def uuid_v4():
    b = bytearray(secrets.token_bytes(16))
    b[6] = (b[6] & 0x0F) | 0x40
    b[8] = (b[8] & 0x3F) | 0x80
    h = b.hex()
    return f"{h[:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:]}"


def call(method, path, token=None, **kw):
    headers = {}
    if method in ("POST", "PUT", "PATCH", "DELETE"):
        headers["Idempotency-Key"] = uuid_v4()
    if token:
        headers["Authorization"] = f"Bearer {token}"
    r = requests.request(method, BASE + path, headers=headers, timeout=60, **kw)
    if r.status_code >= 300:
        sys.exit(f"{method} {path} -> {r.status_code}: {r.text[:300]}")
    return r.json() if r.content else {}


def tinker(php):
    out = subprocess.run(
        ["docker", "exec", "steriqore-app", "php", "artisan", "tinker", "--execute=" + php],
        capture_output=True, text=True, timeout=180,
    )
    return out.stdout.strip()


def main():
    slug = f"zz-web-{secrets.token_hex(3)}"
    password = "Zz-" + secrets.token_urlsafe(14)
    emails = {"owner": f"owner-{slug}@example.com"}
    for role in ROLES:
        emails[role] = f"{role.replace('_', '-')}-{slug}@example.com"

    call("POST", "/v1/tenants", json={
        "tenant_name": "ZZ Cabinet Web", "tenant_slug": slug,
        "owner_name": "Owner Web", "owner_email": emails["owner"], "password": password,
    })
    owner = call("POST", "/v1/auth/login", json={"tenant_slug": slug, "email": emails["owner"], "password": password})
    token = owner["token"]
    owner_id = owner["user"]["id"]

    members = ";".join(
        "$u=App\\Models\\User::create(['name'=>'%s','email'=>'%s','password'=>Illuminate\\Support\\Facades\\Hash::make('%s')]);"
        "App\\Domain\\Identity\\Models\\TenantUser::create(['tenant_id'=>$t->id,'user_id'=>$u->id,'status'=>'active']);"
        "$u->assignRole('%s');" % (role.replace("_", " ").title() + " Web", emails[role], password, role)
        for role in ROLES
    )
    out = tinker(
        "$t=App\\Domain\\Tenancy\\Models\\Tenant::where('slug','%s')->first();"
        "App\\Support\\Tenancy\\TenantContext::run($t,function() use($t){"
        "$s=$t->sites()->firstOrCreate(['name'=>'Cabinet Principal']);"
        "$a=App\\Domain\\Tenancy\\Models\\StorageLocation::create(['tenant_id'=>$t->id,'site_id'=>$s->id,'name'=>'Reserve']);"
        "$b=App\\Domain\\Tenancy\\Models\\StorageLocation::create(['tenant_id'=>$t->id,'site_id'=>$s->id,'name'=>'Bloc']);"
        "$r=app(Spatie\\Permission\\PermissionRegistrar::class);$r->setPermissionsTeamId($t->id);"
        "%s echo 'IDS='.$s->id.','.$a->id.','.$b->id;});" % (slug, members)
    )
    m = re.search(r"IDS=([0-9a-f-]{36}),([0-9a-f-]{36}),([0-9a-f-]{36})", out)
    if not m:
        sys.exit("tinker seed failed: " + out[-300:])
    site_id, reserve, bloc = m.groups()

    device = call("POST", "/v1/devices", token, json={
        "site_id": site_id, "name": "Autoclave Web", "serial_number": "SN-" + secrets.token_hex(4)})
    call("POST", f"/v1/devices/{device['id']}/programs", token, json={
        "name": "Programme 134", "target_temperature_celsius": 134, "plateau_minutes": 18})
    call("POST", "/v1/dlu-rules", token, json={
        "packaging_type": "Sachet", "storage_condition": "Armoire", "shelf_life_days": 180, "reason": "Web"})

    supplier = call("POST", "/v1/suppliers", token, json={"name": "Dental Plus"})
    expiry = (date.today() + timedelta(days=200)).isoformat()
    gloves = call("POST", "/v1/products", token, json={
        "name": "Gants nitrile", "reference": "GN-" + secrets.token_hex(2).upper(),
        "unit": "boite", "min_threshold": 2, "barcode": "3401" + secrets.token_hex(3)})
    masks = call("POST", "/v1/products", token, json={
        "name": "Masques chirurgicaux", "reference": "MC-" + secrets.token_hex(2).upper(), "unit": "boite"})

    # PO 1: fully received -> stock exists (lot in Reserve)
    po1 = call("POST", "/v1/purchase-orders", token, json={
        "supplier_id": supplier["id"], "lines": [{"product_id": gloves["id"], "qty_ordered": 20, "unit_price": 4.5}]})
    call("POST", f"/v1/purchase-orders/{po1['id']}/order", token)
    lot = "LOT-" + secrets.token_hex(2).upper()
    call("POST", f"/v1/purchase-orders/{po1['id']}/receipts", token, json={
        "location_id": reserve, "lines": [{
            "purchase_order_line_id": po1["lines"][0]["id"], "batch_number": lot,
            "expiry_date": expiry, "qty": 20}]})
    # PO 2: ordered, nothing received -> the receipt journey receives it in the UI
    po2 = call("POST", "/v1/purchase-orders", token, json={
        "supplier_id": supplier["id"], "lines": [{"product_id": masks["id"], "qty_ordered": 10, "unit_price": 2.0}]})
    call("POST", f"/v1/purchase-orders/{po2['id']}/order", token)

    # Released cycle with printed labels (scanner / usage journey)
    cycle = call("POST", "/v1/cycles", token, json={"device_id": device["id"]})
    for d in ("Cassette A", "Cassette B", "Cassette C"):
        call("POST", f"/v1/cycles/{cycle['id']}/items", token, json={"description": d})
    for step in ("start", "complete"):
        call("POST", f"/v1/cycles/{cycle['id']}/{step}", token)
    call("POST", f"/v1/cycles/{cycle['id']}/control-tests", token, json={
        "type": "bowie_dick", "result": "pass", "performed_at": "2026-10-02T08:00:00Z"})
    call("POST", f"/v1/cycles/{cycle['id']}/submit-for-release", token)
    call("POST", f"/v1/cycles/{cycle['id']}/release", token, json={"decision": "compliant"})
    labels = call("POST", f"/v1/cycles/{cycle['id']}/labels", token, json={
        "packaging_type": "Sachet", "storage_condition": "Armoire"})
    for lab in labels:
        call("POST", f"/v1/labels/{lab['id']}/print", token)

    patient = call("POST", "/v1/patients", token, json={})
    lab = call("POST", "/v1/laboratories", token, json={"name": "Labo Martin"})

    defines = {
        "API_BASE_URL": BASE,
        "ENV": "dev",
        "WEB_TENANT_SLUG": slug,
        "WEB_PASSWORD": password,
        "WEB_EMAIL_OWNER": emails["owner"],
        **{f"WEB_EMAIL_{r.upper()}": emails[r] for r in ROLES},
        "WEB_OWNER_ID": owner_id,
        "WEB_DEVICE_NAME": "Autoclave Web",
        "WEB_GLOVES_NAME": "Gants nitrile",
        "WEB_GLOVES_BARCODE": gloves["barcode"],
        "WEB_GLOVES_LOT": lot,
        "WEB_MASKS_NAME": "Masques chirurgicaux",
        "WEB_PO_ID": po2["id"],
        "WEB_LABEL_FRESH": labels[0]["id"],
        "WEB_LABEL_SPARE": labels[1]["id"],
        "WEB_PATIENT_ID": patient["id"],
        "WEB_LAB_NAME": "Labo Martin",
        "WEB_RESERVE_ID": reserve,
        "WEB_BLOC_ID": bloc,
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "defines.json").write_text(json.dumps(defines, indent=2), encoding="utf-8")
    print(f"Seeded {slug}; defines written to {OUT / 'defines.json'}")


if __name__ == "__main__":
    main()
