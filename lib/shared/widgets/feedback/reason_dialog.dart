import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// Asks for a short written reason before an action that cannot be undone from
/// the app. Returns the trimmed reason, or null when the user backs out.
/// With [required] the confirm button stays disabled until something is typed.
class ReasonDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String hint;
  final bool required;

  const ReasonDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirmer',
    this.hint = 'Motif',
    this.required = true,
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmer',
    String hint = 'Motif',
    bool required = true,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => ReasonDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        hint: hint,
        required: required,
      ),
    );
  }

  @override
  State<ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<ReasonDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canConfirm => !widget.required || _ctrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            maxLength: 1000,
            decoration: InputDecoration(hintText: widget.hint),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: _canConfirm
              ? () => Navigator.of(context).pop(_ctrl.text.trim())
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
