import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class CycleCreateEmptyDevicesCard extends StatelessWidget {
  final VoidCallback onCreateDevice;
  const CycleCreateEmptyDevicesCard({super.key, required this.onCreateDevice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_outlined,
                  color: AppColors.warning, size: 20),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Aucun appareil disponible',
                  style: AppTypography.bodyStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Pour créer un cycle, vous devez d\'abord ajouter un appareil.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onCreateDevice,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Créer un appareil'),
            ),
          ),
        ],
      ),
    );
  }
}
