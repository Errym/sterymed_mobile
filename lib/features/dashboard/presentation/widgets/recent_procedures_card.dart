import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/models/dashboard_data.dart';

class RecentProceduresCard extends StatelessWidget {
  final List<DashboardRecentProcedure> procedures;
  final VoidCallback onTap;

  const RecentProceduresCard({
    super.key,
    required this.procedures,
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
              const Expanded(
                child: Text(
                  'Actes récents',
                  style: AppTypography.sectionTitle,
                ),
              ),
              TextButton(
                onPressed: onTap,
                child: const Text('Voir tout'),
              ),
            ],
          ),
          if (procedures.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'Aucun acte enregistré récemment.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            Column(
              children: [
                for (final p in procedures)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.label,
                            style: AppTypography.bodyStrong,
                          ),
                        ),
                        Text(p.patientReference, style: AppTypography.caption),
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
