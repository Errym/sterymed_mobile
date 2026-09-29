#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

banner "FIX 1.9 — Haptics on critical actions"

require_repo_root
require_clean_tree

# Files that submit writes and should give light haptic on success,
# heavy haptic on error.
FILES=(
  "lib/features/stock/presentation/screens/stock_issue_screen.dart"
  "lib/features/stock/presentation/screens/stock_adjust_screen.dart"
  "lib/features/stock/presentation/screens/stock_transfer_screen.dart"
  "lib/features/purchases/presentation/screens/goods_receipt_screen.dart"
  "lib/features/labels/presentation/screens/label_usage_form_screen.dart"
)

CHANGED=()

# ── A. Add services import if missing, then insert haptics ─────────────
for FILE in "${FILES[@]}"; do
  if [[ ! -f "$FILE" ]]; then
    warn "Missing file (skipping): $FILE"
    continue
  fi
  backup_file "$FILE"

  python3 - "$FILE" <<'PYEOF'
import sys, io

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

# 1. Ensure services import.
if "package:flutter/services.dart" not in src:
    # insert after "package:flutter/material.dart" import
    src = src.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';",
        1,
    )

# 2. Insert HapticFeedback.lightImpact() before the FIRST AppSnackbar.show
#    in the success branch. Heuristic: find "AppSnackbar.show(\n        context,\n        wasQueued" or "AppSnackbar.show(context, '..."
#    and prepend.
#    We look for a line matching:  "      AppSnackbar.show(" in _submit methods.
import re

# Only insert if not already present.
if "HapticFeedback.lightImpact()" not in src:
    # Insert lightImpact right before the first AppSnackbar.show after
    # "await getIt<...>().issue/adjust/transfer/receive/recordUsage("
    pattern = re.compile(
        r"(\n(\s+)AppSnackbar\.show\(\s*\n?\s*context,)",
    )
    # Only do one substitution for the success path.
    def repl(m):
        indent = m.group(2)
        return "\n" + indent + "HapticFeedback.lightImpact();" + m.group(1)
    src, n = pattern.subn(repl, src, count=1)

# 3. Insert heavyImpact inside every catch block that shows an error snackbar.
if "HapticFeedback.heavyImpact()" not in src:
    pattern2 = re.compile(
        r"(catch\s*\([^)]*\)\s*\{[^}]*?if\s*\(!mounted\)\s*return;\s*)(AppSnackbar\.show\()",
        re.DOTALL,
    )
    def repl2(m):
        return m.group(1) + "HapticFeedback.heavyImpact();\n      " + m.group(2)
    src, n2 = pattern2.subn(repl2, src, count=1)

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print(f"Patched {path}")
PYEOF
  CHANGED+=("$FILE")
done

# ── B. Scanner bloc ───────────────────────────────────────────────────
SCANNER="lib/features/scanner/presentation/bloc/scanner_bloc.dart"
if [[ -f "$SCANNER" ]]; then
  backup_file "$SCANNER"
  python3 - "$SCANNER" <<'PYEOF'
import sys, io

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

if "package:flutter/services.dart" not in src:
    src = src.replace(
        "import 'package:flutter_bloc/flutter_bloc.dart';",
        "import 'package:flutter/services.dart';\nimport 'package:flutter_bloc/flutter_bloc.dart';",
        1,
    )
if "import 'dart:async';" not in src:
    src = "import 'dart:async';\n" + src

# Success: after emitting resolved.
src = src.replace(
    "emit(state.copyWith(status: ScannerStatus.resolved, result: result));",
    "emit(state.copyWith(status: ScannerStatus.resolved, result: result));\n      unawaited(HapticFeedback.lightImpact());",
)

# Error: after emitting error states.
src = src.replace(
    "emit(state.copyWith(\n        status: ScannerStatus.error,\n        error: ex.message,\n        errorCode: ex.code,\n      ));",
    "emit(state.copyWith(\n        status: ScannerStatus.error,\n        error: ex.message,\n        errorCode: ex.code,\n      ));\n      unawaited(HapticFeedback.heavyImpact());",
)
src = src.replace(
    "emit(state.copyWith(\n        status: ScannerStatus.error,\n        error: 'Erreur de lecture : ${ex.toString()}',\n      ));",
    "emit(state.copyWith(\n        status: ScannerStatus.error,\n        error: 'Erreur de lecture.',\n      ));\n      unawaited(HapticFeedback.heavyImpact());",
)

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Patched scanner_bloc.dart")
PYEOF
  CHANGED+=("$SCANNER")
fi

# ── C. Cycle detail screen transitions ────────────────────────────────
CYCLE="lib/features/cycles/presentation/screens/cycle_detail_screen.dart"
if [[ -f "$CYCLE" ]]; then
  backup_file "$CYCLE"
  python3 - "$CYCLE" <<'PYEOF'
import sys, io

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

if "package:flutter/services.dart" not in src:
    src = src.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';",
        1,
    )

# Light haptic before each confirmation dispatch.
for pattern in [
    "context.read<CycleTransitionBloc>().add(StartCycle(id));",
    "context.read<CycleTransitionBloc>().add(CompleteCycle(id));",
    "context.read<CycleTransitionBloc>().add(SubmitCycleForRelease(id));",
]:
    src = src.replace(
        pattern,
        "HapticFeedback.lightImpact();\n      " + pattern,
    )

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Patched cycle_detail_screen.dart")
PYEOF
  CHANGED+=("$CYCLE")
fi

run_analyze
commit_fix "feat(ux): haptic feedback on critical actions" "${CHANGED[@]}"

ok "FIX 1.9 complete"