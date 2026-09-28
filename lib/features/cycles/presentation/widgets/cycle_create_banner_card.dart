import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class CycleCreateBannerCard extends StatelessWidget {
  const CycleCreateBannerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.brandPrimaryLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.add_box_outlined,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cycle de Stérilisation Normé EN 13060',
                  style: AppTypography.bodyStrong,
                ),
                SizedBox(height: 2),
                Text(
                  'Sélectionnez l\'appareil et le programme de la charge.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
