import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class CycleCreateErrorCard extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;
  const CycleCreateErrorCard({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.danger, size: 20),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Impossible de charger les données',
                  style: AppTypography.bodyStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(error, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
            ),
          ),
        ],
      ),
    );
  }
}
