import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../buttons/primary_button.dart';
import '../buttons/secondary_button.dart';

class FormActions extends StatelessWidget {
  final String submitLabel;
  final String cancelLabel;
  final VoidCallback? onSubmit;
  final VoidCallback? onCancel;
  final bool isLoading;
  final bool isSubmittingEnabled;

  const FormActions({
    super.key,
    this.submitLabel = 'Enregistrer',
    this.cancelLabel = 'Annuler',
    this.onSubmit,
    this.onCancel,
    this.isLoading = false,
    this.isSubmittingEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onCancel != null)
          Expanded(
            child: SecondaryButton(
              label: cancelLabel,
              onPressed: isLoading ? null : onCancel,
            ),
          ),
        if (onCancel != null) const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: PrimaryButton(
            label: submitLabel,
            isLoading: isLoading,
            onPressed: isSubmittingEnabled ? onSubmit : null,
          ),
        ),
      ],
    );
  }
}
