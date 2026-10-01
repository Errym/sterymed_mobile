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
        final review =
            state.manualReviewCount +
            state.quarantinedCount +
            (state.localRecoveryRequired ? 1 : 0);
        final online = state.online;

        if (online && pending == 0 && review == 0 && !state.isSyncing) {
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
            ? (
                Icons.cloud_off_outlined,
                AppColors.warning,
                pending > 0 ? '$pending' : '',
              )
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
