import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class CycleCreateSectionLabel extends StatelessWidget {
  final String text;
  const CycleCreateSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          letterSpacing: 0.4,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
