#!/usr/bin/env bash
# Fast lint gate only. Phase scripts run the full test suite before
# their own commits — this hook is a cheap safety net, not a duplicate.
set -e
echo "→ Pre-commit: flutter analyze"
flutter analyze
echo "✅ Pre-commit passed."
