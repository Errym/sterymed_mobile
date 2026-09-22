import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// A labeled quantity stepper backed by a [TextEditingController].
/// Supports direct typing as well as +/- buttons; validated the same
/// way a plain text field would be via [validator].
class QuantityStepper extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int min;
  final int max;
  final String? Function(String?)? validator;

  const QuantityStepper({
    super.key,
    required this.label,
    required this.controller,
    this.min = 1,
    this.max = 999999,
    this.validator,
  });

  int get _value => int.tryParse(controller.text.trim()) ?? min;

  void _setValue(int v) {
    final clamped = v.clamp(min, max);
    controller.text = clamped.toString();
    controller.selection =
        TextSelection.collapsed(offset: controller.text.length);
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: validator,
      initialValue: controller.text,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.label),
            const SizedBox(height: AppSpacing.xs),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: field.hasError
                      ? AppColors.danger
                      : AppColors.borderMedium,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  _StepButton(
                    icon: Icons.remove,
                    onTap: () {
                      _setValue(_value - 1);
                      field.didChange(controller.text);
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: AppTypography.bodyStrong,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      ),
                      onChanged: field.didChange,
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add,
                    onTap: () {
                      _setValue(_value + 1);
                      field.didChange(controller.text);
                    },
                  ),
                ],
              ),
            ),
            if (field.hasError) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                field.errorText!,
                style: AppTypography.caption.copyWith(color: AppColors.danger),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 18, color: AppColors.brandPrimary),
        ),
      ),
    );
  }
}
