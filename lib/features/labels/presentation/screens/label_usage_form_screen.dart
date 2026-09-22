import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../patients/data/models/patient_data.dart';
import '../../../patients/presentation/widgets/patient_picker_sheet.dart';
import '../../data/models/label_data.dart';
import '../../data/repositories/label_usage_repository.dart';

class LabelUsageFormScreen extends StatefulWidget {
  final String labelId;
  final LabelData? label;
  const LabelUsageFormScreen({super.key, required this.labelId, this.label});

  @override
  State<LabelUsageFormScreen> createState() => _LabelUsageFormScreenState();
}

class _LabelUsageFormScreenState extends State<LabelUsageFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _procedureCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  PatientData? _patient;
  bool _submitting = false;

  @override
  void dispose() {
    _procedureCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPatient() async {
    final picked = await PatientPickerSheet.show(context);
    if (picked != null && mounted) {
      setState(() => _patient = picked);
    }
  }

  Future<void> _submit() async {
    if (_patient == null) {
      AppSnackbar.show(context, 'Sélectionnez un patient.',
          kind: SnackKind.warning);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final practitionerId = getIt<SessionStore>().userId ?? '';
    if (practitionerId.isEmpty) {
      AppSnackbar.show(context, 'Session invalide.', kind: SnackKind.error);
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<LabelUsageRepository>().recordUsage(
            labelId: widget.labelId,
            patientId: _patient!.id,
            patientName: _patient!.fullName,
            practitionerId: practitionerId,
            practitionerName: getIt<SessionStore>().userName ?? '',
            procedure: _procedureCtrl.text.trim(),
            notes:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
      if (!mounted) return;
      AppSnackbar.show(context, 'Utilisation enregistrée.',
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
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Enregistrer utilisation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.brandPrimaryLight,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code_2,
                        color: AppColors.brandPrimary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label?.productName ?? 'Étiquette',
                          style: AppTypography.bodyStrong,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.label != null
                              ? [
                                  widget.label!.code,
                                  if (widget.label!.batchNumber != null)
                                    'Lot ${widget.label!.batchNumber}',
                                ].join(' · ')
                              : widget.labelId,
                          style: AppTypography.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionLabel('PATIENT'),
            InkWell(
              onTap: _pickPatient,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InputDecorator(
                decoration: const InputDecoration(
                  hintText: 'Sélectionner un patient',
                  suffixIcon: Icon(Icons.person_search_outlined),
                ),
                child: Text(
                  _patient?.fullName ?? 'Sélectionner un patient',
                  style: AppTypography.body.copyWith(
                    color: _patient == null
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _SectionLabel('ACTE / PROCÉDURE'),
            AppTextField(
              label: 'Procédure',
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          letterSpacing: 0.6,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
