import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/models/dashboard_data.dart';

class TodayCyclesCard extends StatelessWidget {
  final List<DashboardTodayCycle> cycles;
  final VoidCallback onTap;

  const TodayCyclesCard({
    super.key,
    required this.cycles,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cycles du jour',
                  style: AppTypography.sectionTitle,
                ),
              ),
              TextButton(
                onPressed: onTap,
                child: const Text('Voir tout'),
              ),
            ],
          ),
          if (cycles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'Aucun cycle aujourd\'hui.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            Column(
              children: [
                for (final c in cycles)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Cycle ${c.number}',
                            style: AppTypography.bodyStrong,
                          ),
                        ),
                        Text(
                          c.deviceName,
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
