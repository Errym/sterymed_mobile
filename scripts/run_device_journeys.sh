#!/usr/bin/env bash
# Runs the live integration journeys on the attached Android phone, one file at
# a time, each against a freshly seeded clinic (journeys consume stock).
#
#   scripts/run_device_journeys.sh                      # all journeys
#   scripts/run_device_journeys.sh journeys/stock_issue_journey_test.dart ...
#
# Needs the dev backend up on :8010 and the phone on USB (adb reverse is set
# here). Results: build/device-journeys/<name>.log and a PASS/FAIL summary.
set -u
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

# DEVICE_SERIAL=192.168.1.x:5555 runs over Wi-Fi ADB (steadier than a USB cable
# that drops under load); default is the first attached device.
SERIAL="${DEVICE_SERIAL:-$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')}"
[ -n "$SERIAL" ] || { echo "No phone attached."; exit 2; }
curl -fsS -m 5 http://localhost:8010/up >/dev/null || { echo "Backend not answering on :8010."; exit 2; }

if [ "$#" -gt 0 ]; then FILES=("$@"); else
  FILES=(
    web_role_sweep_test.dart
    journeys/auth_journey_test.dart
    journeys/stock_issue_journey_test.dart
    journeys/conflict_409_journey_test.dart
    journeys/goods_receipt_journey_test.dart
    journeys/scanner_usage_journey_test.dart
    journeys/alert_resolve_journey_test.dart
    journeys/cycle_lifecycle_journey_test.dart
    journeys/prosthetic_case_journey_test.dart
    journeys/waiting_placement_journey_test.dart
    web_stock_test.dart
  )
fi

mkdir -p build/device-journeys
adb -s "$SERIAL" shell settings put system screen_off_timeout 1800000
adb -s "$SERIAL" shell svc power stayon usb >/dev/null 2>&1 || true
adb -s "$SERIAL" shell input keyevent KEYCODE_WAKEUP

STATUS=0
for f in "${FILES[@]}"; do
  name="$(basename "$f" .dart)"
  adb -s "$SERIAL" reverse tcp:8010 tcp:8010 >/dev/null
  adb -s "$SERIAL" reverse tcp:9023 tcp:9023 >/dev/null
  python scripts/seed_web_journeys.py >/dev/null 2>&1 || { echo "FAIL  $name (seed)"; STATUS=1; continue; }
  if flutter test "integration_test/$f" -d "$SERIAL" \
      --dart-define-from-file=build/web-journeys/defines.json \
      --dart-define=RUN_LIVE_INTEGRATION_TESTS=true \
      > "build/device-journeys/$name.log" 2>&1; then
    echo "PASS  $name"
  else
    echo "FAIL  $name  (build/device-journeys/$name.log)"; STATUS=1
  fi
done
exit $STATUS
