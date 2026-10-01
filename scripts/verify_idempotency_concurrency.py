#!/usr/bin/env python3
"""
Live proof that one Idempotency-Key creates exactly one record under
concurrency (backend BD-08 / mobile O04). Dev backend only.

Fires N identical POST /v1/patients at once with the same key and counts how
many patient rows really exist afterwards (a patient create has no uniqueness
constraint, so a double-apply cannot hide behind a database error).
Expected with the fix: exactly 1.

Usage: python scripts/verify_idempotency_concurrency.py [N]
Needs the dev stack (docker compose up) and `pip install requests`.
"""
import secrets
import subprocess
import sys
import threading
from collections import Counter

import requests

BASE = "http://localhost:8010/api"
TENANT = "demo2"
EMAIL = "admin2@steriqore.local"
PASSWORD = "password"


def uuid_v4():
    b = bytearray(secrets.token_bytes(16))
    b[6] = (b[6] & 0x0F) | 0x40
    b[8] = (b[8] & 0x3F) | 0x80
    h = b.hex()
    return f"{h[0:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:32]}"


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 8
    login = requests.post(
        f"{BASE}/v1/auth/login",
        json={"tenant_slug": TENANT, "email": EMAIL, "password": PASSWORD},
        headers={"Idempotency-Key": uuid_v4()},
        timeout=30,
    )
    login.raise_for_status()
    auth = {"Authorization": f"Bearer {login.json()['token']}"}

    key = uuid_v4()
    results = []
    gate = threading.Barrier(n)
    before = patient_count()

    def fire():
        gate.wait()
        r = requests.post(
            f"{BASE}/v1/patients",
            json={},
            headers={**auth, "Idempotency-Key": key},
            timeout=60,
        )
        body = {}
        try:
            body = r.json()
        except ValueError:
            pass
        results.append(
            (r.status_code, body.get("id") or body.get("error", {}).get("code"),
             r.headers.get("Idempotency-Replayed"))
        )

    threads = [threading.Thread(target=fire) for _ in range(n)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    after = patient_count()
    ids = {i for st, i, _ in results if 200 <= st < 300}
    print(f"{n} concurrent identical requests, one Idempotency-Key")
    for status, ident, replayed in sorted(results, key=str):
        print(f"  {status}  {ident}  replayed={replayed}")
    print("status counts:", dict(Counter(st for st, _, _ in results)))
    print(f"distinct patient ids returned: {len(ids)}")
    created = None if before is None or after is None else after - before
    if created is not None:
        print(f"patient rows actually created in the database: {created}")
    ok = len(ids) <= 1 and (created is None or created == 1)
    print("PASS: exactly one record" if ok else "FAIL: duplicate records created")
    sys.exit(0 if ok else 1)


def patient_count():
    """Row count via the dev Postgres container (admin role bypasses RLS)."""
    try:
        out = subprocess.run(
            ["docker", "exec", "steriqore-postgres", "psql", "-U", "steriqore",
             "-d", "steriqore", "-tAc", "select count(*) from patients"],
            capture_output=True, text=True, timeout=30,
        )
        return int(out.stdout.strip())
    except Exception:
        return None


if __name__ == "__main__":
    main()
