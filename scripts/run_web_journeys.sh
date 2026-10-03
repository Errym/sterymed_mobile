#!/usr/bin/env bash
# Runs one or more integration_test/<file> in real Chrome against the
# dev backend. Seed first:  python scripts/seed_web_journeys.py
# Needs a chromedriver matching the installed Chrome (set CHROMEDRIVER, default
# build/tools/chromedriver.exe).
#
# Usage: scripts/run_web_journeys.sh web_role_sweep_test.dart [more files]
set -u
cd "$(dirname "$0")/.."
DRIVER="${CHROMEDRIVER:-build/tools/chromedriver.exe}"
DEFINES=build/web-journeys/defines.json
[ -f "$DEFINES" ] || { echo "Seed first: python scripts/seed_web_journeys.py"; exit 2; }
[ -f "$DRIVER" ] || { echo "chromedriver not found at $DRIVER"; exit 2; }

"$DRIVER" --port=4444 > build/web-journeys/chromedriver.log 2>&1 &
DRIVER_PID=$!
trap 'kill $DRIVER_PID 2>/dev/null' EXIT
sleep 2

STATUS=0
for f in "$@"; do
  echo "=== $f"
  flutter drive \
    --driver=integration_test/drivers/integration_test_driver.dart \
    --target="integration_test/$f" \
    -d chrome --browser-name=chrome \
    --dart-define-from-file="$DEFINES" \
    --dart-define=RUN_LIVE_INTEGRATION_TESTS=true || STATUS=1
done
exit $STATUS
