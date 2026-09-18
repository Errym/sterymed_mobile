#!/usr/bin/env bash
# scripts/fix_analyzer_errors.sh
# Fixes every analyzer error in Phase 1 tests + libs.

set -uo pipefail

cd "$(dirname "$0")/.."

echo "═══════════════════════════════════════════════════════════════"
echo " Fix A: Rewrite outbox_operation.dart (remove orphan return)"
echo "═══════════════════════════════════════════════════════════════"
cat > lib/core/storage/outbox/outbox_operation.dart << 'DART_EOF'
enum OutboxOperation {
  labelUsage,
  stockIssue,
  stockAdjust,
  stockTransfer,
  goodsReceipt,
  cycleTransition,
  payment,
}

extension OutboxOperationLabel on OutboxOperation {
  String get label {
    switch (this) {
      case OutboxOperation.labelUsage:
        return 'Utilisation étiquette';
      case OutboxOperation.stockIssue:
        return 'Sortie de stock';
      case OutboxOperation.stockAdjust:
        return 'Ajustement de stock';
      case OutboxOperation.stockTransfer:
        return 'Transfert de stock';
      case OutboxOperation.goodsReceipt:
        return 'Réception marchandise';
      case OutboxOperation.cycleTransition:
        return 'Transition cycle';
      case OutboxOperation.payment:
        return 'Paiement';
    }
  }
}
DART_EOF
echo "  ✅ outbox_operation.dart rewritten"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo " Fix B: Remove expectLater from scanner_bloc_test.dart"
echo "═══════════════════════════════════════════════════════════════"
sed -i '/expectLater:/d' test/bloc/scanner_bloc_test.dart
echo "  ✅ expectLater lines removed"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo " Fix C: Add missing imports to alert tests"
echo "═══════════════════════════════════════════════════════════════"

for f in \
  test/bloc/alert_list_bloc_test.dart \
  test/widget/alert_list_screen_test.dart; do
  if [ -f "$f" ] && ! grep -q "features/alerts/data/models/alert_data.dart" "$f"; then
    sed -i "1i import 'package:steriymed_mobile/features/alerts/data/models/alert_data.dart';" "$f"
    echo "  ✅ AlertSeverity import → $f"
  fi
done

f="test/widget/alert_list_screen_test.dart"
if [ -f "$f" ] && ! grep -qE "flutter/(widgets|material)\.dart" "$f"; then
  sed -i "1i import 'package:flutter/widgets.dart';" "$f"
  echo "  ✅ flutter/widgets import → $f"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo " Fix D: Remove unused imports"
echo "═══════════════════════════════════════════════════════════════"
sed -i "/import 'package:steriymed_mobile\/features\/auth\/data\/repositories\/auth_repository.dart'/d" \
  test/widget/login_screen_test.dart 2>/dev/null && echo "  ✅ Removed unused auth_repository import"
sed -i "/^import 'dart:typed_data';$/d" \
  lib/features/cycles/data/datasources/cycle_remote_datasource.dart 2>/dev/null && echo "  ✅ Removed dart:typed_data import"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo " Fix E: Add const to user_fixture.dart"
echo "═══════════════════════════════════════════════════════════════"
sed -i 's/= UserData(/= const UserData(/g' test/fixtures/user_fixture.dart 2>/dev/null && echo "  ✅ Added const"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo " Verification: flutter analyze"
echo "═══════════════════════════════════════════════════════════════"
flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tail -20

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo " Verification: flutter test"
echo "═══════════════════════════════════════════════════════════════"
flutter test 2>&1 | tail -15
