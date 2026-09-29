#!/usr/bin/env bash
source "$(dirname "$0")/../phase1/_common.sh"

banner "FIX 2.1 — Waiting placement aging summary + prominent badges"

require_repo_root
require_clean_tree

BADGE="lib/shared/widgets/badges/aging_badge.dart"
TILE="lib/features/prosthetic/presentation/widgets/prosthetic_case_tile.dart"
SCREEN="lib/features/prosthetic/presentation/screens/prosthetic_waiting_placement_screen.dart"

backup_file "$BADGE"
backup_file "$TILE"
backup_file "$SCREEN"

# ── 1. Rewrite AgingBadge with `prominent` support ────────────────────
cat > "$BADGE" <<'DART'
import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class AgingBadge extends StatelessWidget {
  final int daysElapsed;

  /// When true, renders a larger, icon-prefixed variant for prominent
  /// contexts (e.g. waiting-for-placement priority tiles).
  final bool prominent;

  const AgingBadge({
    super.key,
    required this.daysElapsed,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;
    late IconData icon;

    if (daysElapsed <= 7) {
      bg = AppColors.agingFresh.withValues(alpha: 0.12);
      fg = AppColors.agingFresh;
      icon = Icons.access_time;
    } else if (daysElapsed <= 14) {
      bg = AppColors.agingMedium.withValues(alpha: 0.15);
      fg = AppColors.agingMedium;
      icon = Icons.warning_amber_outlined;
    } else {
      bg = AppColors.agingUrgent.withValues(alpha: 0.12);
      fg = AppColors.agingUrgent;
      icon = Icons.error_outline;
    }

    final label = '$daysElapsed jour${daysElapsed > 1 ? 's' : ''}';

    if (prominent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
DART
ok "Rewrote $BADGE"

# ── 2. Use prominent in ProstheticCaseTile ────────────────────────────
python3 - "$TILE" <<'PYEOF'
import io, sys

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

if "prominent: true" in src:
    print("Tile already uses prominent:true — skipping")
    sys.exit(0)

# Match any of these older forms:
patterns = [
    "AgingBadge(daysElapsed: item.daysWaitingForPlacement!)",
    "AgingBadge(\n                    daysElapsed: item.daysWaitingForPlacement!,\n                  )",
]
replacement = "AgingBadge(\n                    daysElapsed: item.daysWaitingForPlacement!,\n                    prominent: true,\n                  )"

replaced = False
for p in patterns:
    if p in src:
        src = src.replace(p, replacement, 1)
        replaced = True
        break

if not replaced:
    # Last-resort regex
    import re
    new_src, n = re.subn(
        r"AgingBadge\(\s*daysElapsed:\s*item\.daysWaitingForPlacement!\s*,?\s*\)",
        replacement,
        src,
        count=1,
    )
    if n > 0:
        src = new_src
        replaced = True

if not replaced:
    print("Could not find AgingBadge in tile — inspect manually", file=sys.stderr)
    sys.exit(1)

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Patched tile with prominent:true")
PYEOF

# ── 3. Waiting placement screen — summary bar + filter ────────────────
# If the screen already has an _AgingSummaryBar (you may have built it),
# this is a no-op. Otherwise, insert the summary bar and filter logic.
if grep -q "_AgingSummaryBar" "$SCREEN"; then
  ok "Waiting placement screen already has _AgingSummaryBar — skipping"
else
  python3 - "$SCREEN" <<'PYEOF'
import io, sys, re

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

# 1. Add aging filter state + counts to the state class.
state_marker = "class _ProstheticWaitingPlacementScreenState\n    extends State<ProstheticWaitingPlacementScreen> {"
state_insert = state_marker + """

  String? _agingFilter; // null | 'fresh' | 'medium' | 'urgent'

  int get _freshCount =>
      _items.where((c) => (c.daysWaitingForPlacement ?? 0) <= 7).length;

  int get _mediumCount => _items.where((c) {
        final d = c.daysWaitingForPlacement ?? 0;
        return d >= 8 && d <= 14;
      }).length;

  int get _urgentCount =>
      _items.where((c) => (c.daysWaitingForPlacement ?? 0) >= 15).length;

  List<ProstheticCaseData> get _visibleItems {
    if (_agingFilter == null) return _items;
    return _items.where((c) {
      final d = c.daysWaitingForPlacement ?? 0;
      if (_agingFilter == 'fresh') return d <= 7;
      if (_agingFilter == 'medium') return d >= 8 && d <= 14;
      return d >= 15;
    }).toList();
  }
"""
if state_marker in src:
    src = src.replace(state_marker, state_insert, 1)
else:
    print("State class not found verbatim — inspect manually", file=sys.stderr)
    sys.exit(1)

# 2. Add _AgingSummaryBar widget at end of file.
summary_widget = r'''

class _AgingSummaryBar extends StatelessWidget {
  final int freshCount;
  final int mediumCount;
  final int urgentCount;
  final String? activeFilter;
  final ValueChanged<String?> onFilterSelected;

  const _AgingSummaryBar({
    required this.freshCount,
    required this.mediumCount,
    required this.urgentCount,
    required this.activeFilter,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _chip('fresh', '0-7 j', freshCount, AppColors.agingFresh),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _chip('medium', '8-14 j', mediumCount, AppColors.agingMedium),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _chip('urgent', '15+ j', urgentCount, AppColors.agingUrgent),
          ),
        ],
      ),
    );
  }

  Widget _chip(String key, String label, int count, Color color) {
    final isActive = activeFilter == key;
    return GestureDetector(
      onTap: () => onFilterSelected(isActive ? null : key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isActive ? color : AppColors.borderLight,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: AppTypography.pageTitle.copyWith(color: color, fontSize: 24),
            ),
            Text(label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}
'''
src = src.rstrip() + summary_widget

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Inserted _AgingSummaryBar and filter state")
PYEOF

  warn "You'll need to wire the summary bar into the screen's build() and swap"
  warn "_items for _visibleItems in the list. This part is UI-specific — do it"
  warn "manually to match your exact widget tree, then commit."
fi

run_analyze
commit_fix "feat(prosthetic): prominent aging badges + summary filter scaffolding" "$BADGE" "$TILE" "$SCREEN"

ok "FIX 2.1 complete — verify waiting placement screen manually if it was modified"