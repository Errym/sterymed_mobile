import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Widget? prefix;
  final Widget? suffix;
  final bool enabled;
  final int maxLines;
  final String? errorText;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.prefix,
    this.suffix,
    this.enabled = true,
    this.maxLines = 1,
    this.errorText,
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
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          onChanged: onChanged,
          enabled: enabled,
          maxLines: maxLines,
          style: AppTypography.body,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: prefix,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}
