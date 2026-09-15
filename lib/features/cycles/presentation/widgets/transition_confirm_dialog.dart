import 'package:flutter/material.dart';

import '../../../../shared/widgets/feedback/confirmation_dialog.dart';

abstract final class TransitionConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return ConfirmationDialog.show(
      context,
      title: title,
      message: message,
      confirmLabel: 'Confirmer',
    );
  }
}