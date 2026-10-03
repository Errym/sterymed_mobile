import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class CycleCreateOperatorCard extends StatelessWidget {
  final String name;
  const CycleCreateOperatorCard({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(name, style: AppTypography.bodyStrong),
          const Spacer(),
          const Text('Vous', style: AppTypography.caption),
        ],
      ),
    );
  }
}
