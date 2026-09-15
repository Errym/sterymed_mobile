import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class FormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsets padding;

  const FormSection({
    super.key,
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.brandPrimaryExtraLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.brandPrimaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}
