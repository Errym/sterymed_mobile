#!/usr/bin/env bash
# Git Bash / GNU coreutils runner. Preserve the four existing test groups.
# Flutter writes to a regular file to avoid Windows pipe-related hangs.
set -u

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
OUT="${TEST_OUTPUT_LOG:-build/test_output.log}"
TIMEOUT_SECONDS="${TEST_TIMEOUT_SECONDS:-180}"
if ! [[ "$TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
  echo "TEST_TIMEOUT_SECONDS must be a positive integer." >&2
  exit 2
fi
timeout_version="$(timeout --version 2>/dev/null)" || {
  echo "GNU timeout is required. Run this script in Git Bash, not Windows timeout.exe." >&2
  exit 2
}
if [[ "$timeout_version" != *"GNU coreutils"* ]]; then
  echo "GNU timeout is required; the timeout command on PATH is incompatible." >&2
  exit 2
fi
mkdir -p "$(dirname "$OUT")" || exit 2
: > "$OUT" || exit 2
overall_code=0
group_results=()

run() {
  local label="$1"
  shift
  local code
  printf '\n=== %s ===\n' "$label"
  printf '\n=== %s ===\n' "$label" >> "$OUT"
  timeout --kill-after=10s "${TIMEOUT_SECONDS}s" flutter test "$@" --reporter expanded >> "$OUT" 2>&1
  code=$?
  if [ "$code" -eq 124 ] || [ "$code" -eq 137 ]; then
    group_results+=("$label: TIMED OUT (exit $code)")
  elif [ "$code" -ne 0 ]; then
    group_results+=("$label: FAILED (exit $code)")
  else
    group_results+=("$label: PASSED")
  fi
  # Continue collecting every group, retaining the first failing exit code.
  if [ "$overall_code" -eq 0 ] && [ "$code" -ne 0 ]; then
    overall_code="$code"
  fi
}

run "unit"   test/unit/
run "bloc"   test/bloc/
run "widget" test/widget/
run "golden" test/golden/

printf '\n=== SUMMARY ===\n'
printf '%s\n' "${group_results[@]}"
printf '%s\n' "${group_results[@]}" >> "$OUT"
printf 'Full output: %s\n' "$OUT"
# A summary search finding no match must never mask the test process status.
grep -E 'All tests passed|tests failed|TIMED OUT|\+[0-9]+ -[0-9]+' "$OUT" | tail -20 || true
exit "$overall_code"
