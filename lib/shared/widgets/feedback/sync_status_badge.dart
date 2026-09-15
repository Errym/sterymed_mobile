import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class SyncStatusBadge extends StatelessWidget {
  final int pendingCount;
  final VoidCallback? onTap;

  const SyncStatusBadge({super.key, required this.pendingCount, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (pendingCount == 0) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync, size: 14, color: AppColors.warning),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              '$pendingCount en attente',
              style: AppTypography.caption.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
