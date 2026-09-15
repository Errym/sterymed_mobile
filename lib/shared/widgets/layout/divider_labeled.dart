import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class DividerLabeled extends StatelessWidget {
  final String label;

  const DividerLabeled({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.borderLight)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(label, style: AppTypography.caption),
        ),
        const Expanded(child: Divider(color: AppColors.borderLight)),
      ],
    );
  }
}
