import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class FormFieldWrapper extends StatelessWidget {
  final Widget child;
  final String? helperText;

  const FormFieldWrapper({super.key, required this.child, this.helperText});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        if (helperText != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(helperText!, style: AppTypography.caption),
        ],
      ],
    );
  }
}
