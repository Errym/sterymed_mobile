#!/usr/bin/env bash
# One command to get a freshly seeded practice and the app onto your phone.
#
#   scripts/phone_test_setup.sh            # seed, wire the phone, build + install
#   scripts/phone_test_setup.sh --no-build # seed and wire only (app already installed)
#
# Needs: the dev backend running (docker compose up -d in steriqore), the phone
# on USB with USB debugging on, adb and flutter on PATH.
set -euo pipefail
cd "$(dirname "$0")/.."

SERIAL="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
[ -n "$SERIAL" ] || { echo "No phone found. Plug it in and accept the USB debugging prompt."; exit 1; }
echo "Phone: $SERIAL"

curl -fsS -m 5 http://localhost:8010/up >/dev/null || { echo "Backend is not answering on :8010. Start steriqore first."; exit 1; }

# The phone reaches the laptop through USB, not the network: API (8010) and
# photo/export storage (9023, BUG-010 links).
adb -s "$SERIAL" reverse tcp:8010 tcp:8010
adb -s "$SERIAL" reverse tcp:9023 tcp:9023
# A dimmed screen silently stops touch input mid-test.
adb -s "$SERIAL" shell settings put system screen_off_timeout 1800000
adb -s "$SERIAL" shell svc power stayon usb || true

python scripts/seed_web_journeys.py
python - <<'PY'
import json
d = json.load(open("build/web-journeys/defines.json", encoding="utf-8"))
print("\n=========== LOG IN ON THE PHONE ===========")
print("Cabinet (slug):", d["WEB_TENANT_SLUG"])
print("Password (all):", d["WEB_PASSWORD"])
for role in ("OWNER", "ADMIN", "STOCK_MANAGER", "RELEASER", "PRACTITIONER", "VIEWER"):
    print(f"{role.lower():14}", d["WEB_EMAIL_" + role])
print("===========================================\n")
PY

if [ "${1:-}" != "--no-build" ]; then
  flutter build apk --debug --dart-define=API_BASE_URL=http://localhost:8010/api --dart-define=ENV=dev
  adb -s "$SERIAL" install -r build/app/outputs/flutter-apk/app-debug.apk
  adb -s "$SERIAL" shell monkey -p com.sterymed.mobile -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
fi
echo "Done. Follow docs/DEVICE_TEST_LOG.md for the steps to run and record."
