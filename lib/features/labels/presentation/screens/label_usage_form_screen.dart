import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../data/repositories/label_usage_repository.dart';

class LabelUsageFormScreen extends StatefulWidget {
  final String labelId;
  const LabelUsageFormScreen({super.key, required this.labelId});

  @override
  State<LabelUsageFormScreen> createState() => _LabelUsageFormScreenState();
}

class _LabelUsageFormScreenState extends State<LabelUsageFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientIdCtrl = TextEditingController();
  final _practitionerIdCtrl = TextEditingController();
  final _procedureCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    _practitionerIdCtrl.dispose();
    _procedureCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await context.read<LabelUsageRepository>().recordUsage(
            labelId: widget.labelId,
            patientId: _patientIdCtrl.text.trim(),
            practitionerId: _practitionerIdCtrl.text.trim(),
            procedure: _procedureCtrl.text.trim(),
            notes:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Utilisation enregistrée.',
        kind: SnackKind.success,
      );
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
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Enregistrer utilisation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            AppTextField(
              label: 'Identifiant patient',
              hint: 'ex. 123e4567-...',
              controller: _patientIdCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Identifiant praticien',
              hint: 'ex. 123e4567-...',
              controller: _practitionerIdCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Acte / procédure',
              hint: 'ex. Détartrage, Pose couronne...',
              controller: _procedureCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextArea(
              label: 'Notes (optionnel)',
              controller: _notesCtrl,
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Enregistrer',
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
