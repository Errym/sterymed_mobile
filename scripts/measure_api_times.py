#!/usr/bin/env python3
"""
Cahier §8 "screens under 2 seconds": the SERVER half of that budget.

Times the first-load request(s) of each main screen against the dev backend
(as the practice seeded by scripts/seed_web_journeys.py), 7 runs each, and
fails when the slowest run of any screen exceeds the budget. This measures the
network + API time only. Rendering time on a phone, and the phone's own network,
are a device measurement (docs/DEVICE_TEST_LOG.md, T7.7).

Usage: python scripts/measure_api_times.py [--budget 2.0] [--runs 7]
"""
import argparse
import json
import statistics
import sys
import time
from pathlib import Path

import requests

DEFINES = Path(__file__).resolve().parents[1] / "build" / "web-journeys" / "defines.json"

# screen -> the requests its first load makes (what the app really calls).
# The app fires these in parallel; they are timed one after the other here, so
# the figure is the worst case.
SCREENS = {
    "Accueil (dashboard)": ["/v1/cycles?limit=50", "/v1/alerts?filter[state]=open&limit=50", "/v1/audit-events?limit=20", "/v1/devices?limit=50"],
    "Alertes": ["/v1/alerts?filter[state]=open&limit=20"],
    "Cycles": ["/v1/cycles?limit=20"],
    "Stock": ["/v1/stock-levels?limit=50"],
    "Produits": ["/v1/products?limit=20"],
    "Commandes": ["/v1/purchase-orders?limit=20"],
    "Journal d'audit": ["/v1/audit-events?limit=20"],
    "Recherche de preuves": ["/v1/evidence-search?limit=20"],
    "Prothèses (accueil)": ["/v1/prosthetic-dashboard"],
    "Prothèses (liste)": ["/v1/prosthetic-cases?limit=20", "/v1/prosthetic-cases/summary"],
    "Prothèses (en attente de pose)": ["/v1/prosthetic-cases/waiting-placement?limit=20"],
    "Équipe": ["/v1/members"],
    "Inventaires": ["/v1/inventory-counts?limit=20"],
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--budget", type=float, default=2.0)
    ap.add_argument("--runs", type=int, default=7)
    args = ap.parse_args()

    d = json.loads(DEFINES.read_text(encoding="utf-8"))
    base = d["API_BASE_URL"]
    r = requests.post(
        base + "/v1/auth/login",
        headers={"Idempotency-Key": f"measure-{time.time_ns()}"},
        json={"tenant_slug": d["WEB_TENANT_SLUG"], "email": d["WEB_EMAIL_OWNER"], "password": d["WEB_PASSWORD"]},
        timeout=30,
    )
    r.raise_for_status()
    auth = {"Authorization": "Bearer " + r.json()["token"], "Accept": "application/json"}

    slow = []
    print(f"{'screen':34} {'p50':>7} {'max':>7}  status")
    for screen, paths in SCREENS.items():
        times, bad = [], None
        for _ in range(args.runs):
            spent = 0.0
            for path in paths:
                while True:
                    start = time.perf_counter()
                    resp = requests.get(base + path, headers=auth, timeout=30)
                    took = time.perf_counter() - start
                    if resp.status_code == 429:
                        # The API's own rate limit: wait it out, never time it.
                        time.sleep(float(resp.headers.get("Retry-After", "5")) + 0.5)
                        continue
                    break
                spent += took
                if resp.status_code >= 400 and bad is None:
                    bad = f"{path} -> {resp.status_code}"
            times.append(spent)
        p50, worst = statistics.median(times), max(times)
        ok = bad is None and worst <= args.budget
        print(f"{screen:34} {p50:6.3f}s {worst:6.3f}s  {'OK' if ok else 'FAIL ' + (bad or 'over budget')}")
        if not ok:
            slow.append(screen)

    if slow:
        print(f"\n{len(slow)} screen(s) failed: {', '.join(slow)}")
        sys.exit(1)
    print(f"\nALL within {args.budget:.1f}s (server side only)")


if __name__ == "__main__":
    main()
