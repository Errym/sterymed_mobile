#!/usr/bin/env python3
"""
T9.4 / BUG-010 live proof: a file uploaded through the API comes back as a link
that can be opened from OUTSIDE the Docker network, and a tampered link is
refused. Uses the practice seeded by scripts/seed_web_journeys.py.

  upload a small image to a cycle (POST /cycles/{id}/attachments-base64)
  -> list the attachments -> the link host is NOT the internal `minio`
  -> GET the link from this machine -> 200 and the same bytes
  -> change one character of the signature -> 403

On a phone the storage address must also be reachable from the phone
(dev: adb reverse tcp:9023 tcp:9023; staging: the public storage host).

Usage: python scripts/verify_media_links.py
"""
import base64
import json
import secrets
import sys
from pathlib import Path
from urllib.parse import urlsplit

import requests

D = json.loads((Path(__file__).resolve().parents[1] / "build" / "web-journeys" / "defines.json").read_text(encoding="utf-8"))
BASE = D["API_BASE_URL"]
FAILED = []

# 1x1 transparent PNG
PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
)


def check(label, ok, detail=""):
    print(("PASS  " if ok else "FAIL  ") + label + (f"  ({detail})" if detail else ""))
    if not ok:
        FAILED.append(label)


def call(method, path, token=None, **kw):
    headers = {"Accept": "application/json"}
    if method == "POST":
        headers["Idempotency-Key"] = secrets.token_hex(16)
    if token:
        headers["Authorization"] = "Bearer " + token
    return requests.request(method, BASE + path, headers=headers, timeout=60, **kw)


def main():
    token = call("POST", "/v1/auth/login", json={
        "tenant_slug": D["WEB_TENANT_SLUG"], "email": D["WEB_EMAIL_OWNER"], "password": D["WEB_PASSWORD"],
    }).json()["token"]
    device = call("GET", "/v1/devices?limit=1", token).json()["data"][0]["id"]
    cycle = call("POST", "/v1/cycles", token, json={"device_id": device}).json()
    cycle_id = (cycle.get("data") or cycle)["id"]

    up = call("POST", f"/v1/cycles/{cycle_id}/attachments-base64", token, json={
        "file_name": "probe.png", "file_data": base64.b64encode(PNG).decode(),
    })
    check("photo uploaded", up.status_code in (200, 201), f"{up.status_code} {up.text[:120]}")
    listing = call("GET", f"/v1/cycles/{cycle_id}/attachments", token).json()
    rows = listing.get("data", listing) if isinstance(listing, dict) else listing
    check("the attachment is listed", len(rows) == 1)
    url = rows[0].get("url") or rows[0].get("download_url") or ""
    host = urlsplit(url).hostname or ""
    check("the link host is not the internal storage host", host not in ("", "minio"), host)

    got = requests.get(url, timeout=30)
    check("the link opens from outside the Docker network", got.status_code == 200, str(got.status_code))
    check("and returns the uploaded bytes", got.content == PNG)

    sig = url.rsplit("X-Amz-Signature=", 1)
    bad = sig[0] + "X-Amz-Signature=" + ("0" if sig[1][0] != "0" else "1") + sig[1][1:]
    check("a tampered signature is refused", requests.get(bad, timeout=30).status_code == 403)

    print()
    if FAILED:
        print("FAILED:", FAILED)
        sys.exit(1)
    print("ALL PASS")


if __name__ == "__main__":
    main()
