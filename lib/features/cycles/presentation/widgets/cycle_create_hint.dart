import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class CycleCreateHint extends StatelessWidget {
  final String text;
  const CycleCreateHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(text, style: AppTypography.caption),
    );
  }
}
