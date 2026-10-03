import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

enum StatusTone { neutral, success, warning, danger, info }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusTone tone;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;
    switch (tone) {
      case StatusTone.success:
        bg = AppColors.successLight;
        fg = AppColors.success;
        break;
      case StatusTone.warning:
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        break;
      case StatusTone.danger:
        bg = AppColors.dangerLight;
        fg = AppColors.danger;
        break;
      case StatusTone.info:
        bg = AppColors.infoLight;
        fg = AppColors.info;
        break;
      case StatusTone.neutral:
        bg = AppColors.backgroundMuted;
        fg = AppColors.textSecondary;
        break;
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
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
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 6),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
