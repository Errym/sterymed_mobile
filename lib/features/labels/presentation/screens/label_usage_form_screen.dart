import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../identity/data/models/practitioner_option.dart';
import '../../../identity/data/repositories/practitioner_repository.dart';
import '../../../patients/data/models/patient_data.dart';
import '../../../patients/presentation/widgets/patient_picker_sheet.dart';
import '../../data/local/label_usage_draft_store.dart';
import '../../data/models/label_scan_result.dart';
import '../../data/repositories/label_usage_repository.dart';

class LabelUsageFormScreen extends StatefulWidget {
  final String labelId;
  final LabelScanResult? label;
  const LabelUsageFormScreen({super.key, required this.labelId, this.label});

  @override
  State<LabelUsageFormScreen> createState() => _LabelUsageFormScreenState();
}

class _LabelUsageFormScreenState extends State<LabelUsageFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _procedureCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _draftDebouncer = Debouncer(delay: const Duration(milliseconds: 400));
  final _drafts = getIt<LabelUsageDraftStore>();
  PatientData? _patient;
  bool _submitting = false;
  bool _restoredDraft = false;
  // Who performed the act. Defaults to the signed-in user. The list is a
  // convenience: if it cannot be loaded (offline), the signed-in user is used,
  // exactly as before, so recording a usage is never blocked by it.
  String? _practitionerId;
  List<PractitionerOption> _practitioners = const [];

  @override
  void initState() {
    super.initState();
    final draft = _drafts.load(widget.labelId);
    if (draft != null) {
      _patient = draft.patient;
      _procedureCtrl.text = draft.procedure;
      _notesCtrl.text = draft.notes;
      _restoredDraft = !draft.isEmpty;
    }
    _procedureCtrl.addListener(_saveDraft);
    _notesCtrl.addListener(_saveDraft);
    _practitionerId = getIt<SessionStore>().userId;
    _loadPractitioners();
  }

  Future<void> _loadPractitioners() async {
    try {
      final people = await getIt<PractitionerRepository>().list();
      if (!mounted) return;
      final ids = people.map((p) => p.id).toSet();
      setState(() {
        _practitioners = people;
        // The signed-in user stays selected only while the server would accept
        // them; otherwise the user must choose.
        if (_practitionerId != null && !ids.contains(_practitionerId)) {
          _practitionerId = people.length == 1 ? people.first.id : null;
        }
      });
    } catch (_) {
      // Keep the signed-in user (see above).
    }
  }

  void _saveDraft() {
    _draftDebouncer.run(() {
      _drafts.save(
        widget.labelId,
        LabelUsageDraft(
          patientId: _patient?.id,
          patientReference: _patient?.reference,
          procedure: _procedureCtrl.text,
          notes: _notesCtrl.text,
        ),
      );
    });
  }

  @override
  void dispose() {
    _draftDebouncer.dispose();
    _procedureCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPatient() async {
    final picked = await PatientPickerSheet.show(context);
    if (picked != null && mounted) {
      setState(() => _patient = picked);
      _saveDraft();
    }
  }

  Future<void> _submit() async {
    if (_patient == null) {
      AppSnackbar.show(
        context,
        'Sélectionnez un patient.',
        kind: SnackKind.warning,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final practitionerId = _practitionerId ?? '';
    if (practitionerId.isEmpty) {
      AppSnackbar.show(
        context,
        _practitioners.isEmpty
            ? 'Session invalide.'
            : 'Choisissez un praticien.',
        kind: _practitioners.isEmpty ? SnackKind.error : SnackKind.warning,
      );
      return;
    }
    final session = getIt<SessionStore>();
    final fromList = _practitioners
        .where((p) => p.id == practitionerId)
        .map((p) => p.name)
        .firstOrNull;
    final practitionerName =
        fromList ??
        (practitionerId == session.userId ? session.userName : null);
    setState(() => _submitting = true);
    try {
      final result = await context.read<LabelUsageRepository>().recordUsage(
        labelId: widget.labelId,
        patientId: _patient!.id,
        patientReference: _patient!.reference,
        practitionerId: practitionerId,
        practitionerName: practitionerName,
        procedure: _procedureCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      await _drafts.clear(widget.labelId);
      if (!mounted) return;
      final wasQueued = result.isQueued;
      AppSnackbar.show(
        context,
        wasQueued
            ? 'Enregistré localement. Synchronisation en attente.'
            : 'Utilisation enregistrée.',
        kind: wasQueued ? SnackKind.queued : SnackKind.success,
        actionLabel: wasQueued ? 'Voir la file' : null,
        onAction: wasQueued ? () => context.push(Routes.sync) : null,
      );
      context.popOrGo(Routes.scanner);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Enregistrer utilisation'),
        leading: AppBackButton.maybe(context),
      ),
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
                    child: const Icon(
                      Icons.qr_code_2,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label != null
                              ? '${widget.label!.deviceName} · Cycle ${widget.label!.cycleNumber}'
                              : 'Étiquette',
                          style: AppTypography.bodyStrong,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.label?.siteName ?? widget.labelId,
                          style: AppTypography.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_restoredDraft) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Brouillon restauré depuis votre dernière saisie.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                  _patient?.reference ?? 'Sélectionner un patient',
                  style: AppTypography.body.copyWith(
                    color: _patient == null
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            if (_practitioners.length > 1) ...[
              const SizedBox(height: AppSpacing.md),
              const _SectionLabel('PRATICIEN'),
              AppDropdown<String?>(
                label: 'Praticien',
                value: _practitionerId,
                options: [
                  if (_practitionerId == null)
                    const AppDropdownOption(
                      value: null,
                      label: 'Choisir un praticien',
                    ),
                  ..._practitioners.map(
                    (p) => AppDropdownOption(value: p.id, label: p.name),
                  ),
                ],
                onChanged: (v) => setState(() => _practitionerId = v),
              ),
            ],
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
