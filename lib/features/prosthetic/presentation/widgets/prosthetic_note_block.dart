import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class ProstheticNoteBlock extends StatelessWidget {
  final String label;
  final String text;
  const ProstheticNoteBlock(
      {super.key, required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: 4),
          Text(text, style: AppTypography.body),
        ],
      ),
    );
  }
}
