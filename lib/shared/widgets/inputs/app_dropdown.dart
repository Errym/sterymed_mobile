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

  /// Label shown for a saved value that is no longer among the options
  /// (archived, deleted, or its lookup failed to load).
  static const unavailableLabel = 'Choix actuel (indisponible)';

  @override
  Widget build(BuildContext context) {
    // A saved value missing from the options must stay selectable and visible:
    // DropdownButtonFormField asserts when its value has no matching item, and
    // silently replacing it would change the record the next time it is saved.
    final shown = [
      ...options,
      if (value != null && !options.any((o) => o.value == value))
        AppDropdownOption<T>(value: value as T, label: unavailableLabel),
    ];
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
          items: shown
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
