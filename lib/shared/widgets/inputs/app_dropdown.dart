import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class AppDropdownOption<T> {
  final T value;
  final String label;
  const AppDropdownOption({required this.value, required this.label});
}

class AppDropdown<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final T? value;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;
  final bool enabled;

  const AppDropdown({
    super.key,
    this.label,
    this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
    this.validator,
    this.enabled = true,
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
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          hint: hint != null
              ? Text(
                  hint!,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textTertiary,
                  ),
                )
              : null,
          items: options
              .map(
                (o) => DropdownMenuItem<T>(
                  value: o.value,
                  child: Text(o.label, style: AppTypography.body),
                ),
              )
              .toList(),
          onChanged: enabled ? onChanged : null,
          validator: validator,
          style: AppTypography.body,
        ),
      ],
    );
  }
}
