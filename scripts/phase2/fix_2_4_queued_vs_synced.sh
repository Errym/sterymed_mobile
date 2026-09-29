#!/usr/bin/env bash
source "$(dirname "$0")/../phase1/_common.sh"

banner "FIX 2.4 — Queued vs synced feedback (audit + patch)"

require_repo_root
require_clean_tree

MODELS=(
  "lib/features/stock/data/models/stock_movement_data.dart"
  "lib/features/purchases/data/models/goods_receipt_data.dart"
  "lib/features/labels/data/models/label_usage_data.dart"
  "lib/features/cycles/data/models/cycle_data.dart"
  "lib/features/cycles/data/models/cycle_release_data.dart"
)

SCREENS=(
  "lib/features/stock/presentation/screens/stock_issue_screen.dart"
  "lib/features/stock/presentation/screens/stock_adjust_screen.dart"
  "lib/features/stock/presentation/screens/stock_transfer_screen.dart"
  "lib/features/purchases/presentation/screens/goods_receipt_screen.dart"
  "lib/features/labels/presentation/screens/label_usage_form_screen.dart"
  "lib/features/cycles/presentation/screens/cycle_detail_screen.dart"
)

MISSING_MODELS=()
MISSING_SCREENS=()

# ── Audit models ──────────────────────────────────────────────────────
for m in "${MODELS[@]}"; do
  if [[ ! -f "$m" ]]; then
    warn "Model not found: $m"
    continue
  fi
  if grep -q "final bool isQueued;" "$m"; then
    ok "Model has isQueued: $m"
  else
    MISSING_MODELS+=("$m")
    warn "Model MISSING isQueued: $m"
  fi
done

# ── Audit screens ─────────────────────────────────────────────────────
for s in "${SCREENS[@]}"; do
  if [[ ! -f "$s" ]]; then
    warn "Screen not found: $s"
    continue
  fi
  if grep -q "result.isQueued\|wasQueued\|SnackKind.queued" "$s"; then
    ok "Screen handles queued: $s"
  else
    MISSING_SCREENS+=("$s")
    warn "Screen MISSING queued handling: $s"
  fi
done

echo ""
if [[ ${#MISSING_MODELS[@]} -eq 0 && ${#MISSING_SCREENS[@]} -eq 0 ]]; then
  ok "All models and screens already handle isQueued — nothing to patch"
  exit 0
fi

warn "Missing pieces found. Patching..."

# ── Patch missing models ──────────────────────────────────────────────
for m in "${MISSING_MODELS[@]}"; do
  backup_file "$m"
  python3 - "$m" <<'PYEOF'
import io, re, sys

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

# 1. Add final bool isQueued; field after the last "final" field.
if "final bool isQueued;" not in src:
    # Find the constructor and add field before it.
    ctor = re.search(r"\n\s*const \w+\(\{", src)
    if ctor:
        insert_at = ctor.start()
        src = src[:insert_at] + "\n  /// True when this result came from the offline outbox path.\n  final bool isQueued;\n" + src[insert_at:]

# 2. Add to constructor with default.
src = re.sub(
    r"(this\.createdAt[^,)]*)(,\s*)\}\s*\)",
    r"\1,\n    this.isQueued = false,\n  })",
    src,
    count=1,
)

# 3. Add to fromJson.
src = re.sub(
    r"(createdAt:\s*[^,]+,\s*\n\s*)\);",
    r"\1        isQueued: json['is_queued'] as bool? ?? false,\n      );",
    src,
    count=1,
)

# 4. Add to props.
src = re.sub(
    r"(List<Object\?> get props\s*=>\s*\[)",
    r"\1 isQueued,",
    src,
    count=1,
)

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print(f"Patched {path}")
PYEOF
done

# ── Screens: real work is manual ──────────────────────────────────────
if [[ ${#MISSING_SCREENS[@]} -gt 0 ]]; then
  echo ""
  warn "The following screens still need manual queued-vs-synced wiring:"
  for s in "${MISSING_SCREENS[@]}"; do
    warn "  $s"
  done
  warn ""
  warn "Pattern to apply in each screen (after the repository call):"
  warn ""
  cat <<'PATTERN'
  final result = await getIt<XRepository>().write(...);
  if (!mounted) return;
  if (result.isQueued) {
    AppSnackbar.show(
      context,
      'Enregistré localement. Synchronisation en attente.',
      kind: SnackKind.queued,
      actionLabel: 'Voir la file',
      onAction: () => context.push(Routes.sync),
    );
  } else {
    AppSnackbar.show(context, 'Écriture enregistrée.', kind: SnackKind.success);
  }
PATTERN
fi

run_analyze
run_tests
commit_fix "fix(offline): audit + patch queued vs synced feedback" \
  "${MISSING_MODELS[@]}" 2>/dev/null || true

ok "FIX 2.4 complete — fix any remaining screens manually, then commit"