import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../buttons/primary_button.dart';
import '../buttons/secondary_button.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirmer',
    this.cancelLabel = 'Annuler',
    this.isDestructive = false,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmer',
    String cancelLabel = 'Annuler',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(title, style: AppTypography.sectionTitle),
      content: Text(message, style: AppTypography.body),
      actions: [
        SizedBox(
          width: 120,
          child: SecondaryButton(
            label: cancelLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        SizedBox(
          width: 140,
          child: isDestructive
              ? TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    confirmLabel,
                    style: AppTypography.buttonLabel.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                )
              : PrimaryButton(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
        ),
      ],
    );
  }
}
