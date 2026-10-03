#!/usr/bin/env python3
"""
BUG-026 live proof: practices registered back-to-back must each work at once,
with NO `permission:cache-reset` in between. Registers 4 practices, then calls a
permission-gated route with every owner's token, many times over, in an
interleaved order (so every Octane worker serves every practice).

Usage: python scripts/verify_two_practices.py
"""
import secrets
import sys
import time

import requests

BASE = "http://localhost:8010/api"
FAILED = []


def key():
    return secrets.token_hex(16)


def call(method, path, token=None, **kw):
    headers = {"Accept": "application/json", "Idempotency-Key": key()}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    for _ in range(8):
        r = requests.request(method, BASE + path, headers=headers, timeout=60, **kw)
        if r.status_code == 429:
            time.sleep(float(r.headers.get("Retry-After", "5")) + 0.5)
            continue
        return r
    return r


def main():
    owners = []
    for i in range(4):
        slug = "zz-two-" + secrets.token_hex(3)
        pw = "Zz-" + secrets.token_urlsafe(14)
        email = f"owner-{slug}@example.com"
        reg = call("POST", "/v1/tenants", json={"tenant_name": "Two " + slug, "tenant_slug": slug,
                                                "owner_name": "O", "owner_email": email, "password": pw})
        assert reg.status_code in (200, 201), reg.text[:200]
        token = call("POST", "/v1/auth/login", json={"tenant_slug": slug, "email": email, "password": pw}).json()["token"]
        owners.append((slug, token))
        # right away, no reset: the practice that was JUST created must work
        r = call("GET", "/v1/sites", token)
        ok = r.status_code == 200
        print(("PASS  " if ok else "FAIL  ") + f"practice {i + 1} works immediately after registering  ({r.status_code})")
        if not ok:
            FAILED.append(f"fresh practice {i + 1}")

    bad = 0
    total = 0
    for _ in range(25):
        for slug, token in owners:
            for path in ("/v1/sites", "/v1/prosthetic-dashboard", "/v1/products"):
                total += 1
                if call("GET", path, token).status_code != 200:
                    bad += 1
    ok = bad == 0
    print(("PASS  " if ok else "FAIL  ") + f"{total} interleaved calls across 4 practices, none refused  ({bad} refused)")
    if not ok:
        FAILED.append("interleaved calls")

    if FAILED:
        print("FAILED:", FAILED)
        sys.exit(1)
    print("ALL PASS")


if __name__ == "__main__":
    main()
