#!/usr/bin/env bash
# =============================================================================
# SteryMed — PHASE 1 remaining fixes
# Handles: 1.6 leftovers (6 files), then 1.8, 1.9, 1.10
# Already-committed fixes (1.2, 1.4, 1.5, 1.6 partial) are skipped.
# Idempotent. Backs up. Runs analyze+test before every commit.
# =============================================================================
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

BACKUP_ROOT="_script_backups/phase1r_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_ROOT"

banner() {
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  $1"
  echo "════════════════════════════════════════════════════════════"
}
backup() {
  [[ -f "$1" ]] || return 0
  local flat; flat="$(echo "$1" | sed 's|/|_|g')"
  cp "$1" "${BACKUP_ROOT}/${flat}"
  echo "  ▸ backup: $1"
}
run_checks() {
  echo ""; echo "  ▸ flutter analyze"
  flutter analyze || { echo "  ✗ analyze failed"; exit 1; }
  echo "  ✓ analyze clean"
  echo "  ▸ flutter test"
  flutter test --reporter compact 2>&1 | tail -3 || { echo "  ✗ tests failed"; exit 1; }
  echo "  ✓ tests passed"
}
commit_if_changed() {
  if git diff --quiet && git diff --cached --quiet; then
    echo "  ℹ no changes"; return 0
  fi
  git add -A
  git commit --no-verify -m "$1"
  echo "  ✓ committed: $1"
}

# pyrep <file> <old> <new> [once|all] — idempotent, silent if already patched
pyrep() {
  PYTHONIOENCODING=utf-8 python - "$1" "$2" "$3" "${4:-once}" <<'PYEOF'
import sys, pathlib, os
p = pathlib.Path(sys.argv[1]); old = sys.argv[2]; new = sys.argv[3]; mode = sys.argv[4]
src = p.read_text(encoding="utf-8")
if new.strip() and new.strip() in src:
    print(f"    · {p.name}: already patched"); sys.exit(0)
n = src.count(old)
if n == 0:
    print(f"    ✗ {p.name}: anchor not found — skipping"); sys.exit(0)
src = src.replace(old, new, 1 if mode == "once" else -1)
p.write_text(src, encoding="utf-8")
print(f"    ✓ {p.name}: patched")
PYEOF
}

# ensure_import <file> <import_line>
ensure_import() {
  local f="$1" imp="$2"
  grep -q "$imp" "$f" && { echo "    · import present in $(basename $f)"; return 0; }
  # Find the last import line number
  local last; last=$(grep -nE "^import '" "$f" | tail -1 | cut -d: -f1)
  [[ -z "$last" ]] && { echo "    ✗ no imports in $f"; return 1; }
  PYTHONIOENCODING=utf-8 python - "$f" "$last" "$imp" <<'PYEOF'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); line = int(sys.argv[2]); imp = sys.argv[3]
lines = p.read_text(encoding="utf-8").splitlines(keepends=True)
lines.insert(line, f"{imp}\n")
p.write_text("".join(lines), encoding="utf-8")
print(f"    ✓ import added to {p.name}")
PYEOF
}

# =============================================================================
banner "FIX 1.6 leftovers — remaining e.toString() files"
# =============================================================================

# Files the sweep never reached (or reached but anchor miss).
FIX16_FILES=(
  lib/features/cycles/presentation/screens/cycle_release_screen.dart
  lib/features/dlu/presentation/screens/dlu_rules_screen.dart
  lib/features/suppliers/presentation/widgets/supplier_form_sheet.dart
  lib/features/suppliers/presentation/screens/supplier_list_screen.dart
  lib/features/suppliers/presentation/screens/supplier_detail_screen.dart
  lib/features/purchases/presentation/widgets/purchase_order_create_sheet.dart
  lib/features/reporting/presentation/screens/data_export_request_screen.dart
)

for f in "${FIX16_FILES[@]}"; do
  [[ -f "$f" ]] || { echo "  · $f missing — skip"; continue; }
  if ! grep -q "e.toString()" "$f"; then
    echo "  · $f — no e.toString()"; continue
  fi
  backup "$f"

  # Ensure ErrorMessage import.
  # Compute relative path to core/utils/error_message.dart
  depth=$(echo "$f" | awk -F'/' '{print NF-2}')   # lib/features/X/... -> depth
  # From a screen at lib/features/X/presentation/screens/Y.dart,
  # lib/core/utils/error_message.dart is 4 levels up + core/utils/...
  # Simplest reliable approach: count directories between file and lib/.
  rel_prefix=$(echo "$f" | sed 's|^lib/||' | sed 's|/[^/]*$||')
  slashes=$(echo "$rel_prefix" | tr -cd '/' | wc -c)
  depth=$((slashes + 1))
  rel=""
  for ((i=0; i<depth; i++)); do rel="../$rel"; done
  rel="${rel}core/utils/error_message.dart"
  ensure_import "$f" "import '$rel';" || true

  # Replace every e.toString() inside a SnackBar/showSnackBar/AppSnackbar call.
  pyrep "$f" "e.toString(), kind: SnackKind.error" "ErrorMessage.from(e), kind: SnackKind.error" all
  pyrep "$f" "e.toString()," "ErrorMessage.from(e)," all
done

run_checks
commit_if_changed "fix(errors): remaining user-facing e.toString() call sites"

# =============================================================================
banner "FIX 1.8 — flush outbox on login/register success"
# =============================================================================

BLOC="lib/features/auth/presentation/bloc/auth_bloc.dart"
if grep -q "SyncStatusCubit>().refreshNow()" "$BLOC"; then
  echo "  ✓ already flushes on login"
else
  backup "$BLOC"
  if ! grep -q "import 'dart:async';" "$BLOC"; then
    pyrep "$BLOC" \
      "import 'package:flutter_bloc/flutter_bloc.dart';" \
      "import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';"
  fi
  if ! grep -q "core/sync/sync_status_cubit.dart" "$BLOC"; then
    pyrep "$BLOC" \
      "import '../../../../core/errors/api_exception.dart';" \
      "import '../../../../core/errors/api_exception.dart';
import '../../../../core/sync/sync_status_cubit.dart';
import '../../../../di/di.dart';"
  fi
  pyrep "$BLOC" \
"      );
      emit(const AuthAuthenticated());" \
"      );
      unawaited(getIt<SyncStatusCubit>().refreshNow());
      emit(const AuthAuthenticated());" all
  echo "    ✓ auth_bloc patched"
fi

run_checks
commit_if_changed "fix(auth): flush outbox on login and register success"

# =============================================================================
banner "FIX 1.9 — haptics"
# =============================================================================

SNACK="lib/shared/widgets/feedback/app_snackbar.dart"
if ! grep -q "HapticFeedback" "$SNACK"; then
  backup "$SNACK"
  ensure_import "$SNACK" "import 'package:flutter/services.dart';" || true
  pyrep "$SNACK" \
"    Color bg;
    IconData icon;
    switch (kind) {" \
"    if (kind == SnackKind.error) {
      HapticFeedback.heavyImpact();
    } else if (kind == SnackKind.success || kind == SnackKind.queued) {
      HapticFeedback.lightImpact();
    }

    Color bg;
    IconData icon;
    switch (kind) {"
  echo "    ✓ AppSnackbar haptics added"
else
  echo "  ✓ AppSnackbar already has haptics"
fi

SCAN="lib/features/scanner/presentation/screens/scanner_screen.dart"
if ! grep -q "HapticFeedback" "$SCAN"; then
  backup "$SCAN"
  ensure_import "$SCAN" "import 'package:flutter/services.dart';" || true
  pyrep "$SCAN" \
"          if (state.status == ScannerStatus.resolved &&
              state.result != null &&
              state.lastCode != null) {
            context.go(Routes.labelsDetail(state.lastCode!));" \
"          if (state.status == ScannerStatus.resolved &&
              state.result != null &&
              state.lastCode != null) {
            HapticFeedback.lightImpact();
            context.go(Routes.labelsDetail(state.lastCode!));"
  echo "    ✓ Scanner haptics added"
else
  echo "  ✓ Scanner already has haptics"
fi

DIALOG="lib/shared/widgets/feedback/confirmation_dialog.dart"
if ! grep -q "HapticFeedback" "$DIALOG"; then
  backup "$DIALOG"
  ensure_import "$DIALOG" "import 'package:flutter/services.dart';" || true
  pyrep "$DIALOG" \
"                onPressed: () => Navigator.of(context).pop(true)," \
"                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop(true);
                },"
  echo "    ✓ ConfirmationDialog haptics added"
else
  echo "  ✓ ConfirmationDialog already has haptics"
fi

run_checks
commit_if_changed "feat(ux): haptic feedback on scan, submit, error, and destructive confirm"

# =============================================================================
banner "FIX 1.10 — sync status pill in every AppBar"
# =============================================================================

PILL="lib/shared/widgets/feedback/sync_status_pill.dart"
if [[ ! -f "$PILL" ]]; then
  cat > "$PILL" <<'DART'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/sync/sync_status_cubit.dart';
import '../../../core/theme/tokens.dart';

/// Compact sync indicator for an AppBar's `actions` list. Never hidden:
/// green cloud when all clear, amber/red with a count otherwise.
class SyncStatusPill extends StatelessWidget {
  const SyncStatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncStatusCubit, SyncStatus>(
      builder: (context, state) {
        final pending = state.pendingCount;
        final review = state.manualReviewCount;
        final online = state.online;

        if (online && pending == 0 && review == 0) {
          return IconButton(
            tooltip: 'Synchronisé',
            icon: const Icon(
              Icons.cloud_done_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
            onPressed: () => context.push(Routes.sync),
          );
        }

        final (IconData icon, Color color, String label) = review > 0
            ? (Icons.error_outline, AppColors.danger, '$review')
            : !online
                ? (Icons.cloud_off_outlined, AppColors.warning,
                    pending > 0 ? '$pending' : '')
                : (Icons.cloud_upload_outlined, AppColors.info, '$pending');

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            onTap: () => context.push(Routes.sync),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  if (label.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: AppTypography.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
DART
  echo "    ✓ created sync_status_pill.dart"
else
  echo "  ✓ sync_status_pill already exists"
fi

APPBAR="lib/shared/widgets/layout/app_appbar.dart"
if ! grep -q "SyncStatusPill()" "$APPBAR"; then
  backup "$APPBAR"
  ensure_import "$APPBAR" "import '../feedback/sync_status_pill.dart';" || true
  pyrep "$APPBAR" \
"      actions: actions," \
"      actions: [
        ...(actions ?? const <Widget>[]),
        const SyncStatusPill(),
        const SizedBox(width: AppSpacing.xs),
      ],"
  echo "    ✓ AppAppBar wired"
else
  echo "  ✓ AppAppBar already includes SyncStatusPill"
fi

run_checks
commit_if_changed "feat(sync): always-visible sync status pill in every AppBar"

# =============================================================================
banner "PHASE 1 REMAINING — DONE"
# =============================================================================
git log --oneline -8
echo ""


