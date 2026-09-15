import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class AppTextArea extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final int maxLines;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const AppTextArea({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.maxLines = 4,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTypography.label),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          onChanged: onChanged,
          style: AppTypography.body,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
