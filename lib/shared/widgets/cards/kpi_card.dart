import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accent;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.brandPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.brandPrimaryExtraLight,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: AppTypography.kpiNumber.copyWith(color: color),
              ),
              const SizedBox(height: 2),
              Text(label, style: AppTypography.label),
            ],
          ),
        ),
      ),
    );
  }
}
