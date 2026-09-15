import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class OfflineBanner extends StatelessWidget {
  final String? message;

  const OfflineBanner({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: AppColors.warningLight,
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 16, color: AppColors.warning),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message ??
                  'Mode hors ligne — les modifications seront synchronisées',
              style: AppTypography.caption.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}
