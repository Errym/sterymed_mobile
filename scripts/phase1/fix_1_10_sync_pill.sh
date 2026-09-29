#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

banner "FIX 1.10 — Always-visible sync pill"

require_repo_root
require_clean_tree

PILL="lib/shared/widgets/feedback/sync_status_pill.dart"
APPBAR="lib/shared/widgets/layout/app_appbar.dart"
SYNC="lib/features/sync/presentation/screens/sync_queue_screen.dart"

backup_file "$APPBAR"
backup_file "$SYNC"

# ── 1. Create the pill widget ─────────────────────────────────────────
mkdir -p "$(dirname "$PILL")"
cat > "$PILL" <<'DART'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/sync/sync_status_cubit.dart';
import '../../../core/theme/tokens.dart';

/// Compact, always-visible sync indicator for an AppBar's `actions` slot.
///
///   - Green check:  online, nothing pending
///   - Amber cloud-upload + count: pending writes queued (online)
///   - Red cloud-off + count:    offline, N queued
///   - Red error + count:        N items in manual review
///
/// Tapping navigates to the sync queue.
class SyncStatusPill extends StatelessWidget {
  const SyncStatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncStatusCubit, SyncStatus>(
      buildWhen: (a, b) =>
          a.online != b.online ||
          a.pendingCount != b.pendingCount ||
          a.manualReviewCount != b.manualReviewCount ||
          a.isSyncing != b.isSyncing,
      builder: (context, state) {
        final hasReview = state.manualReviewCount > 0;
        final hasPending = state.pendingCount > 0;
        final offline = !state.online;

        Color color;
        IconData icon;
        String label;

        if (hasReview) {
          color = AppColors.danger;
          icon = Icons.error_outline;
          label = '${state.manualReviewCount}';
        } else if (offline) {
          color = AppColors.danger;
          icon = Icons.cloud_off;
          label = hasPending ? '${state.pendingCount}' : '';
        } else if (hasPending) {
          color = AppColors.warning;
          icon = Icons.cloud_upload_outlined;
          label = '${state.pendingCount}';
        } else {
          color = AppColors.success;
          icon = Icons.cloud_done_outlined;
          label = '';
        }

        return InkWell(
          onTap: () => context.push(Routes.sync),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
DART
ok "Created $PILL"

# ── 2. Rewrite AppAppBar to include the pill by default ───────────────
cat > "$APPBAR" <<'DART'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/tokens.dart';
import '../feedback/sync_status_pill.dart';

/// SteryMed AppBar.
///
/// Two modes:
///   - [navy] = true  → deep navy header (list/detail screens)
///   - [navy] = false → white header (form screens)
///
/// By default, a compact [SyncStatusPill] is appended to the actions row.
/// Set [showSyncPill] to `false` on screens that already surface sync
/// state prominently (e.g. the sync queue itself).
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final bool navy;
  final bool showSyncPill;

  const AppAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBack = true,
    this.navy = true,
    this.showSyncPill = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final bg = navy ? AppColors.navyHeader : AppColors.backgroundApp;
    final fg = navy ? AppColors.navyHeaderText : AppColors.textPrimary;

    final resolvedActions = <Widget>[
      if (actions != null) ...actions!,
      if (showSyncPill) const SyncStatusPill(),
    ];

    return AppBar(
      title: Text(title),
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: navy
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            )
          : null,
      leading: leading ??
          (showBack && Navigator.of(context).canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null),
      actions: resolvedActions.isEmpty ? null : resolvedActions,
      bottom: navy
          ? null
          : const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: AppColors.borderLight),
            ),
    );
  }
}
DART
ok "Rewrote $APPBAR"

# ── 3. Opt out on the sync queue screen ───────────────────────────────
python3 - "$SYNC" <<'PYEOF'
import sys, io

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

# Replace the sync screen's AppBar to opt out of the pill.
# Match the current AppBar construction.
src = src.replace(
    "appBar: AppAppBar(\n        title: 'File de synchronisation',",
    "appBar: AppAppBar(\n        title: 'File de synchronisation',\n        showSyncPill: false,",
)

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Patched sync_queue_screen.dart")
PYEOF

run_analyze
commit_fix "feat(sync): always-visible sync status pill in AppBar" "$PILL" "$APPBAR" "$SYNC"

ok "FIX 1.10 complete"