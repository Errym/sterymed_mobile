#!/usr/bin/env bash
# Runs the same steps CI runs (.github/workflows/) so you can catch a
# failure before pushing instead of after. Mirrors each workflow's actual
# command — if a workflow's command changes, update it here too; this
# script is a convenience, not a replacement for CI, and CI's result is
# always the one that counts.
set -e

cd "$(git rev-parse --show-toplevel)"

echo "=================================================================="
echo "1/5  mobile-analyze.yml — flutter analyze --fatal-infos"
echo "=================================================================="
flutter analyze --fatal-infos

echo
echo "=================================================================="
echo "2/5  mobile-test.yml — flutter test --coverage"
echo "=================================================================="
flutter test --coverage

echo
echo "=================================================================="
echo "3/5  mobile-build-android.yml — flutter build apk --debug"
echo "=================================================================="
flutter build apk --debug

echo
echo "=================================================================="
echo "4/5  mobile-build-ios.yml — flutter build ios --simulator --no-codesign"
echo "=================================================================="
if [[ "$(uname -s)" == "Darwin" ]]; then
  flutter build ios --simulator --no-codesign
else
  echo "Skipped — this workflow only runs on macOS (runs-on: macos-latest)"
  echo "in CI; can't be reproduced on $(uname -s). Also currently a known,"
  echo "tracked CI failure regardless of platform (missing ios/Podfile) —"
  echo "see mobile-build-ios.yml's own comment and docs/CICD.md."
fi

echo
echo "=================================================================="
echo "5/5  secrets-scan.yml — gitleaks"
echo "=================================================================="
if command -v docker >/dev/null 2>&1; then
  # Full git-history scan, matching gitleaks-action@v2's own default mode
  # (not a --no-git working-tree scan, which false-positives on build
  # artifacts like .dart_tool/ — see docs/SECURITY.md).
  MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd):/repo" zricethezav/gitleaks:latest \
    detect --source=/repo --redact
else
  echo "Skipped — Docker not found. Install Docker or run:"
  echo "  gitleaks detect --source . --redact"
  echo "directly if you have the gitleaks CLI installed instead."
fi

echo
echo "=================================================================="
echo "All local CI steps completed. This does not run"
echo "mobile-release-android.yml / mobile-release-ios.yml (both empty"
echo "stubs — Phase 10, see docs/CICD.md) or dependabot."
echo "=================================================================="
