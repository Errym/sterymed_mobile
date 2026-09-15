import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class AgingBadge extends StatelessWidget {
  final int daysElapsed;

  const AgingBadge({super.key, required this.daysElapsed});

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;

    if (daysElapsed <= 7) {
      bg = AppColors.agingFresh.withValues(alpha: 0.12);
      fg = AppColors.agingFresh;
    } else if (daysElapsed <= 14) {
      bg = AppColors.agingMedium.withValues(alpha: 0.15);
      fg = AppColors.agingMedium;
    } else {
      bg = AppColors.agingLate.withValues(alpha: 0.12);
      fg = AppColors.agingLate;
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
        '$daysElapsed jour${daysElapsed > 1 ? 's' : ''}',
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
