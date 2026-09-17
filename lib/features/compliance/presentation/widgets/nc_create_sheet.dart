import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../cycles/data/models/cycle_data.dart';
import '../../../cycles/data/repositories/cycle_repository.dart';
import '../../../labels/data/repositories/label_repository.dart';
import '../../data/repositories/non_conformity_repository.dart';

class NcCreateSheet extends StatefulWidget {
  const NcCreateSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => const NcCreateSheet(),
    );
  }

  @override
  State<NcCreateSheet> createState() => _NcCreateSheetState();
}

class _NcCreateSheetState extends State<NcCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelCodeCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  List<CycleData> _cycles = [];
  String _subjectType = 'cycle';
  String? _cycleId;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadCycles();
  }

  @override
  void dispose() {
    _labelCodeCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCycles() async {
    try {
      final cycles =
          await getIt<CycleRepository>().list(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _cycles = cycles;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    String? subjectId;

    if (_subjectType == 'cycle') {
      subjectId = _cycleId;
      if (subjectId == null) {
        AppSnackbar.show(context, 'Sélectionnez un cycle.',
            kind: SnackKind.warning);
        return;
      }
    } else {
      // Label: resolve the scanned code into a label UUID via the backend.
      final code = _labelCodeCtrl.text.trim();
      if (code.isEmpty) {
        AppSnackbar.show(context, 'Saisissez un code d\'étiquette.',
            kind: SnackKind.warning);
        return;
      }
      setState(() => _submitting = true);
      try {
        final result = await getIt<LabelRepository>().getByCode(code);
        if (result.label == null) {
          if (!mounted) return;
          AppSnackbar.show(
            context,
            'Étiquette introuvable pour ce code.',
            kind: SnackKind.error,
          );
          setState(() => _submitting = false);
          return;
        }
        subjectId = result.label!.id;
      } catch (e) {
        if (!mounted) return;
        AppSnackbar.show(context, 'Erreur : $e', kind: SnackKind.error);
        setState(() => _submitting = false);
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      await getIt<NonConformityRepository>().create(
        subjectType: _subjectType,
        subjectId: subjectId,
        description: _descriptionCtrl.text.trim(),
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Non-conformité enregistrée.',
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
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: _loading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : Form(
              key: _formKey,
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Text('Nouvelle non-conformité',
                      style: AppTypography.sectionTitle),
                  const SizedBox(height: AppSpacing.md),
                  AppDropdown<String>(
                    label: 'Type de sujet',
                    value: _subjectType,
                    options: const [
                      AppDropdownOption(value: 'cycle', label: 'Cycle'),
                      AppDropdownOption(value: 'label', label: 'Étiquette'),
                    ],
                    onChanged: (v) =>
                        setState(() => _subjectType = v ?? 'cycle'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_subjectType == 'cycle')
                    _cycles.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Text(
                              'Aucun cycle disponible. Créez un cycle d\'abord.',
                              style: AppTypography.caption,
                            ),
                          )
                        : AppDropdown<String>(
                            label: 'Cycle concerné *',
                            value: _cycleId,
                            options: _cycles
                                .map((c) => AppDropdownOption(
                                      value: c.id,
                                      label:
                                          'Cycle ${c.number} · ${c.deviceName}',
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _cycleId = v),
                          )
                  else
                    AppTextField(
                      label: 'Code d\'étiquette *',
                      hint: 'Scannez ou saisissez le code',
                      controller: _labelCodeCtrl,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Requis.'
                          : null,
                    ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextArea(
                    label: 'Description *',
                    controller: _descriptionCtrl,
                    maxLines: 4,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Enregistrer la non-conformité',
                    isLoading: _submitting,
                    onPressed: (_subjectType == 'cycle' && _cycles.isEmpty)
                        ? null
                        : _submit,
                  ),
                ],
              ),
            ),
    );
  }
}
