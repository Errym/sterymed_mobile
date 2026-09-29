import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/formatters/date_formatter.dart';
import '../../data/models/control_test_data.dart';

/// Control test row shown inline on the cycle detail screen. Distinct from
/// [ControlTestRow] (uses [StatusBadge], used on the dedicated cycle
/// control tests list screen).
class CycleDetailControlTestRow extends StatelessWidget {
  final ControlTestData test;
  const CycleDetailControlTestRow({super.key, required this.test});

  @override
  Widget build(BuildContext context) {
    final isPass = test.result == ControlTestResult.pass;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(test.type.label, style: AppTypography.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  AppDateFormatter.dateTime(test.performedAt),
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isPass ? AppColors.successLight : AppColors.dangerLight,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              test.result.label,
              style: AppTypography.caption.copyWith(
                color: isPass ? AppColors.success : AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
