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
      fg = AppColors.warningText;
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
