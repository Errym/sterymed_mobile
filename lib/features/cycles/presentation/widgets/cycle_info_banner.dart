import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class CycleInfoBanner extends StatelessWidget {
  final String message;
  const CycleInfoBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.info),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(color: AppColors.info),
            ),
          ),
        ],
      ),
    );
  }
}
