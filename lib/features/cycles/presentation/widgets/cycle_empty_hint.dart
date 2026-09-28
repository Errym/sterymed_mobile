import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class CycleEmptyHint extends StatelessWidget {
  final String text;
  const CycleEmptyHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(text, style: AppTypography.caption),
    );
  }
}
