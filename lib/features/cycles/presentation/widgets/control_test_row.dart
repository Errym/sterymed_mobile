import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../data/models/control_test_data.dart';

class ControlTestRow extends StatelessWidget {
  final ControlTestData test;
  const ControlTestRow({super.key, required this.test});

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
                  DateFormat('dd/MM/yyyy HH:mm').format(test.performedAt),
                  style: AppTypography.caption,
                ),
                if (test.operatorName != null) ...[
                  const SizedBox(height: 2),
                  Text(test.operatorName!, style: AppTypography.caption),
                ],
              ],
            ),
          ),
          StatusBadge(
            label: test.result.label,
            tone: isPass ? StatusTone.success : StatusTone.danger,
          ),
        ],
      ),
    );
  }
}
