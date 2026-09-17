import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class SyncStatusBanner extends StatelessWidget {
  final bool online;
  final int pendingCount;
  final int manualReviewCount;
  final VoidCallback? onTap;

  const SyncStatusBanner({
    super.key,
    required this.online,
    required this.pendingCount,
    this.manualReviewCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Nothing pending → hide entirely.
    if (online && pendingCount == 0 && manualReviewCount == 0) {
      return const SizedBox.shrink();
    }

    Color bg;
    Color fg;
    IconData icon;
    String label;

    if (manualReviewCount > 0) {
      bg = AppColors.dangerLight;
      fg = AppColors.danger;
      icon = Icons.error_outline;
      label = '$manualReviewCount élément(s) à vérifier';
    } else if (!online) {
      bg = AppColors.warningLight;
      fg = AppColors.warning;
      icon = Icons.cloud_off;
      label =
          'Hors ligne${pendingCount > 0 ? ' — $pendingCount en attente' : ''}';
    } else {
      bg = AppColors.infoLight;
      fg = AppColors.info;
      icon = Icons.sync;
      label = '$pendingCount synchronisation(s) en attente';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          color: bg,
          child: Row(
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right, size: 16, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
