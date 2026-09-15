import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class SyncIndicator extends StatelessWidget {
  final bool online;
  final int pendingCount;

  const SyncIndicator({
    super.key,
    this.online = true,
    this.pendingCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (online && pendingCount == 0) return const SizedBox.shrink();

    final isOffline = !online;
    final bg = isOffline ? AppColors.warningLight : AppColors.infoLight;
    final fg = isOffline ? AppColors.warning : AppColors.info;
    final icon = isOffline ? Icons.cloud_off : Icons.sync;
    final label = isOffline ? 'Hors ligne' : '$pendingCount en attente';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
