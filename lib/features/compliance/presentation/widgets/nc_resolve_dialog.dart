import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../data/repositories/non_conformity_repository.dart';

class NcResolveDialog extends StatefulWidget {
  final String ncId;
  const NcResolveDialog({super.key, required this.ncId});

  static Future<bool?> show(BuildContext context, {required String ncId}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => NcResolveDialog(ncId: ncId),
    );
  }

  @override
  State<NcResolveDialog> createState() => _NcResolveDialogState();
}

class _NcResolveDialogState extends State<NcResolveDialog> {
  final _resolutionCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _resolutionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_resolutionCtrl.text.trim().isEmpty) {
      AppSnackbar.show(context, 'Saisissez une résolution.',
          kind: SnackKind.warning);
      return;
    }
    setState(() => _submitting = true);
    try {
      await getIt<NonConformityRepository>().resolve(
        widget.ncId,
        resolution: _resolutionCtrl.text.trim(),
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Non-conformité résolue.',
          kind: SnackKind.success);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: const Text(
        'Résoudre la non-conformité',
        style: AppTypography.sectionTitle,
      ),
      content: SingleChildScrollView(
        child: AppTextArea(
          label: 'Description de la résolution',
          controller: _resolutionCtrl,
          maxLines: 4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        SizedBox(
          width: 140,
          child: PrimaryButton(
            label: 'Résoudre',
            isLoading: _submitting,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}
