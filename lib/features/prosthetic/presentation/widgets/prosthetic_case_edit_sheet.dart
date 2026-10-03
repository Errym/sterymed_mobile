import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_date_picker.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../data/models/laboratory_data.dart';
import '../../data/models/prosthetic_case_data.dart';
import '../../data/repositories/prosthetic_repository.dart';

/// Brief page 7: "The page must include ... Quick Edit ... actions."
/// Edits exactly the clinical-side fields `UpdateProstheticCaseRequest`
/// accepts (`laboratory_id`, `impression_type`, `work_type`,
/// `impression_date`, `sent_to_lab_date`, `returned_from_lab_date`,
/// `planned_placement_date`, `priority`, `notes`, `internal_comments`).
/// Deliberately excludes two backend-supported fields:
///   - `practitioner_id`: real on the backend, but this app has no
///     accessible "pick a practitioner" list for a non-admin user (the
///     only member list, `GET /v1/members`, is gated on
///     `invitations.create`) — not fabricating a picker with nowhere
///     real to source its options from.
///   - `actual_placement_date`: not in `UpdateProstheticCaseRequest` at
///     all; the backend sets it only via the `placed` status transition
///     (`ChangeProstheticCaseStatusAction`), matching the brief's own
///     workflow rule that every status change is what writes history.
/// Payment fields are a separate, already-built form
/// (`ProstheticPaymentSection`) gated on a different permission
/// (`prosthetic_payments.manage`) and are not touched here.
class ProstheticCaseEditSheet extends StatefulWidget {
  const ProstheticCaseEditSheet({super.key, required this.caseData});

  final ProstheticCaseData caseData;

  static Future<bool?> show(BuildContext context, ProstheticCaseData data) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => ProstheticCaseEditSheet(caseData: data),
    );
  }

  @override
  State<ProstheticCaseEditSheet> createState() =>
      _ProstheticCaseEditSheetState();
}

class _ProstheticCaseEditSheetState extends State<ProstheticCaseEditSheet> {
  late final TextEditingController _priorityCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _internalCommentsCtrl;

  late String? _laboratoryId;
  late ProstheticImpressionType _impressionType;
  late ProstheticWorkType _workType;
  late DateTime _impressionDate;
  DateTime? _sentToLabDate;
  DateTime? _returnedFromLabDate;
  DateTime? _plannedPlacementDate;

  List<LaboratoryData> _laboratories = [];
  bool _loadingLabs = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final c = widget.caseData;
    _priorityCtrl = TextEditingController(text: c.priority ?? '');
    _notesCtrl = TextEditingController(text: c.notes ?? '');
    _internalCommentsCtrl = TextEditingController(
      text: c.internalComments ?? '',
    );
    _laboratoryId = c.laboratoryId;
    _impressionType = c.impressionType;
    _workType = c.workType;
    _impressionDate = c.impressionDate;
    _sentToLabDate = c.sentToLabDate;
    _returnedFromLabDate = c.returnedFromLabDate;
    _plannedPlacementDate = c.plannedPlacementDate;
    _loadLaboratories();
  }

  @override
  void dispose() {
    _priorityCtrl.dispose();
    _notesCtrl.dispose();
    _internalCommentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLaboratories() async {
    try {
      final labs = await getIt<ProstheticRepository>().listLaboratories();
      if (!mounted) return;
      setState(() {
        // The case's current laboratory stays selectable even once archived:
        // dropping it would blank the field and silently unassign it on save.
        _laboratories = labs
            .where((l) => !l.archived || l.id == _laboratoryId)
            .toList();
        _loadingLabs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingLabs = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await getIt<ProstheticRepository>().update(widget.caseData.id, {
        'laboratory_id': _laboratoryId,
        'impression_type': _impressionType.wire,
        'work_type': _workType.wire,
        'impression_date': _impressionDate.toIso8601String().split('T').first,
        'sent_to_lab_date': _sentToLabDate?.toIso8601String().split('T').first,
        'returned_from_lab_date': _returnedFromLabDate
            ?.toIso8601String()
            .split('T')
            .first,
        'planned_placement_date': _plannedPlacementDate
            ?.toIso8601String()
            .split('T')
            .first,
        'priority': _priorityCtrl.text.trim().isEmpty
            ? null
            : _priorityCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'internal_comments': _internalCommentsCtrl.text.trim().isEmpty
            ? null
            : _internalCommentsCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
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
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Modifier le dossier',
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<ProstheticImpressionType>(
              label: 'Type d\'empreinte',
              value: _impressionType,
              options: ProstheticImpressionType.values
                  .map((t) => AppDropdownOption(value: t, label: t.label))
                  .toList(),
              onChanged: (v) => setState(
                () => _impressionType = v ?? ProstheticImpressionType.digital,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<ProstheticWorkType>(
              label: 'Type de travail',
              value: _workType,
              options: ProstheticWorkType.values
                  .map((t) => AppDropdownOption(value: t, label: t.label))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _workType = v ?? ProstheticWorkType.crown),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDatePicker(
              label: 'Date d\'empreinte',
              value: _impressionDate,
              lastDate: DateTime.now(),
              onChanged: (d) => setState(() => _impressionDate = d),
            ),
            const SizedBox(height: AppSpacing.md),
            _loadingLabs
                ? const SizedBox(
                    height: 48,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : AppDropdown<String?>(
                    label: 'Laboratoire',
                    value: _laboratoryId,
                    options: [
                      const AppDropdownOption(value: null, label: 'Aucun'),
                      ..._laboratories.map(
                        (l) => AppDropdownOption(
                          value: l.id,
                          label: l.archived ? '${l.name} (archivé)' : l.name,
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _laboratoryId = v),
                  ),
            const SizedBox(height: AppSpacing.md),
            AppDatePicker(
              label: 'Date d\'envoi au laboratoire',
              value: _sentToLabDate,
              lastDate: DateTime.now(),
              onChanged: (d) => setState(() => _sentToLabDate = d),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDatePicker(
              label: 'Date de retour du laboratoire',
              value: _returnedFromLabDate,
              lastDate: DateTime.now(),
              onChanged: (d) => setState(() => _returnedFromLabDate = d),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDatePicker(
              label: 'Date de pose prévue',
              value: _plannedPlacementDate,
              onChanged: (d) => setState(() => _plannedPlacementDate = d),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Priorité',
              controller: _priorityCtrl,
              hint: 'Normale, urgente…',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextArea(
              label: 'Remarques',
              controller: _notesCtrl,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextArea(
              label: 'Commentaires internes',
              controller: _internalCommentsCtrl,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Enregistrer',
              isLoading: _submitting,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
