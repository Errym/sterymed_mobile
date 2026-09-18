import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class ItemEditorResult {
  final String description;
  const ItemEditorResult({required this.description});
}

class ItemEditorDialog extends StatefulWidget {
  final String? initialDescription;

  const ItemEditorDialog({super.key, this.initialDescription});

  static Future<ItemEditorResult?> show(
    BuildContext context, {
    String? initialDescription,
  }) {
    return showDialog<ItemEditorResult>(
      context: context,
      builder: (_) => ItemEditorDialog(
        initialDescription: initialDescription,
      ),
    );
  }

  @override
  State<ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends State<ItemEditorDialog> {
  late final TextEditingController _descCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      setState(() => _error = 'Description obligatoire.');
      return;
    }
    Navigator.of(context).pop(ItemEditorResult(description: desc));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialDescription != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(
        isEdit ? 'Modifier l\'instrument' : 'Ajouter un instrument',
        style: AppTypography.sectionTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _descCtrl,
              autofocus: true,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: 'Description *',
                hintText: 'Ex : Cassette chirurgicale',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: AppColors.info),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Le lot de traçabilité se lie plus tard, depuis '
                      'l\'onglet Stock ou en scannant une étiquette.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.info,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
        ),
      ],
    );
  }
}
