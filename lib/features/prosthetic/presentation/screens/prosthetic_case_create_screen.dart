import 'package:flutter/material.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_date_picker.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/searchable_picker_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../patients/data/models/patient_data.dart';
import '../../../patients/data/repositories/patient_repository.dart';
import '../../data/local/prosthetic_case_draft_store.dart';
import '../../../identity/data/models/practitioner_option.dart';
import '../../../identity/data/repositories/practitioner_repository.dart';
import '../../data/models/laboratory_data.dart';
import '../../data/repositories/prosthetic_repository.dart';

class ProstheticCaseCreateScreen extends StatefulWidget {
  const ProstheticCaseCreateScreen({super.key});

  @override
  State<ProstheticCaseCreateScreen> createState() =>
      _ProstheticCaseCreateScreenState();
}

class _ProstheticCaseCreateScreenState
    extends State<ProstheticCaseCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priorityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _internalCommentsCtrl = TextEditingController();

  PatientData? _patient;
  String _impressionType = 'digital';
  String _workType = 'crown';
  DateTime _impressionDate = DateTime.now();
  String? _laboratoryId;
  List<LaboratoryData> _laboratories = [];
  bool _loadingLabs = true;
  String? _labsError;
  String? _practitionerId;
  List<PractitionerOption> _practitioners = [];
  bool _loadingPractitioners = true;
  String? _practitionersError;
  bool _submitting = false;

  ProstheticCaseDraftStore get _draftStore => getIt<ProstheticCaseDraftStore>();

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    _loadLaboratories();
    _loadPractitioners();
  }
    @override
  void dispose() {
    _priorityCtrl.dispose();
    _notesCtrl.dispose();
    _internalCommentsCtrl.dispose();
    super.dispose();
  }

  void _restoreDraft() {
    final draft = _draftStore.load();
    if (draft == null) return;
    setState(() {
      if (draft.patientId != null) {
        _patient = PatientData(
          id: draft.patientId!,
          reference: draft.patientReference ?? '',
        );
      }
      _laboratoryId = draft.laboratoryId;
      _practitionerId = draft.practitionerId;
      _impressionType = draft.impressionType;
      _workType = draft.workType;
      _impressionDate = draft.impressionDate ?? DateTime.now();
      _priorityCtrl.text = draft.priority;
      _notesCtrl.text = draft.notes;
      _internalCommentsCtrl.text = draft.internalComments;
    });
  }

  /// Every draft write goes through one chain, in order. Without it a save
  /// that started a moment before "Créer" could finish AFTER the draft was
  /// cleared and bring the already-submitted case back as a draft.
  Future<void> _draftChain = Future<void>.value();
  bool _draftClosed = false;

  /// Durable on every change (brief §14: "avoid silent data loss"): the form
  /// survives the app being killed at any moment, not just a clean exit.
  Future<void> _saveDraft() {
    if (_draftClosed) return _draftChain;
    final draft = ProstheticCaseDraft(
      patientId: _patient?.id,
      patientReference: _patient?.reference,
      laboratoryId: _laboratoryId,
      practitionerId: _practitionerId,
      impressionType: _impressionType,
      workType: _workType,
      impressionDate: _impressionDate,
      priority: _priorityCtrl.text,
      notes: _notesCtrl.text,
      internalComments: _internalCommentsCtrl.text,
    );
    return _draftChain = _draftChain
        .then((_) => _draftStore.save(draft))
        .catchError((_) {});
  }

  /// After a successful submit: wait for any save already in flight, drop the
  /// draft, and refuse every later save.
  Future<void> _closeDraft() {
    _draftClosed = true;
    return _draftChain = _draftChain
        .then((_) => _draftStore.clear())
        .catchError((_) {});
  }

  Future<void> _loadLaboratories() async {
    setState(() {
      _loadingLabs = true;
      _labsError = null;
    });
    try {
      final labs = await getIt<ProstheticRepository>().listLaboratories();
      if (!mounted) return;
      setState(() {
        _laboratories = labs.where((l) => !l.archived).toList();
        _loadingLabs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLabs = false;
        _labsError = ErrorMessage.from(e);
      });
    }
  }

  /// Loads who may be named as practitioner. The server's own rule decides, so
  /// the list never offers someone the server would reject. Defaults to the
  /// signed-in user when they are on it; a draft choice that is no longer valid
  /// (left the practice, changed role) is dropped rather than submitted.
  Future<void> _loadPractitioners() async {
    setState(() {
      _loadingPractitioners = true;
      _practitionersError = null;
    });
    try {
      final people = await getIt<PractitionerRepository>().list();
      if (!mounted) return;
      final ids = people.map((p) => p.id).toSet();
      final self = getIt<SessionStore>().userId;
      setState(() {
        _practitioners = people;
        if (_practitionerId != null && !ids.contains(_practitionerId)) {
          _practitionerId = null;
        }
        _practitionerId ??= self != null && ids.contains(self)
            ? self
            : (people.length == 1 ? people.first.id : null);
        _loadingPractitioners = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPractitioners = false;
        _practitionersError = ErrorMessage.from(e);
      });
    }
  }

  Future<void> _pickPatient() async {
    final selected = await showModalBottomSheet<PatientData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => const _PatientPickerSheet(),
    );
    if (selected != null) {
      setState(() => _patient = selected);
      _saveDraft();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_patient == null) {
      AppSnackbar.show(context, 'Sélectionnez un patient.',
          kind: SnackKind.warning);
      return;
    }

    final practitionerId = _practitionerId;
    if (practitionerId == null || practitionerId.isEmpty) {
      AppSnackbar.show(context, 'Choisissez un praticien.',
          kind: SnackKind.error);
      return;
    }

    setState(() => _submitting = true);
    try {
      await getIt<ProstheticRepository>().create({
        'patient_id': _patient!.id,
        'practitioner_id': practitionerId,
        if (_laboratoryId != null) 'laboratory_id': _laboratoryId,
        'impression_type': _impressionType,
        'work_type': _workType,
        'impression_date': _impressionDate.toIso8601String().split('T').first,
        if (_priorityCtrl.text.trim().isNotEmpty)
          'priority': _priorityCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
        if (_internalCommentsCtrl.text.trim().isNotEmpty)
          'internal_comments': _internalCommentsCtrl.text.trim(),
      });
      await _closeDraft();
      if (!mounted) return;
      AppSnackbar.show(context, 'Dossier prothétique créé.',
          kind: SnackKind.success);
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
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Nouveau dossier prothétique'),
      body: Form(
        key: _formKey,
        onChanged: _saveDraft,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const Text('Patient *', style: AppTypography.label),
            const SizedBox(height: AppSpacing.xs),
            InkWell(
              onTap: _pickPatient,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _patient?.reference ?? 'Sélectionner un patient',
                        style: _patient == null
                            ? AppTypography.body
                                .copyWith(color: AppColors.textTertiary)
                            : AppTypography.bodyStrong,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String>(
              label: 'Type d\'empreinte *',
              value: _impressionType,
              options: const [
                AppDropdownOption(value: 'digital', label: 'Numérique'),
                AppDropdownOption(value: 'physical', label: 'Physique'),
              ],
              onChanged: (v) {
                setState(() => _impressionType = v ?? 'digital');
                _saveDraft();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String>(
              label: 'Type de travail *',
              value: _workType,
              options: const [
                AppDropdownOption(value: 'crown', label: 'Couronne'),
                AppDropdownOption(value: 'bridge', label: 'Bridge'),
                AppDropdownOption(value: 'implant', label: 'Implant'),
                AppDropdownOption(value: 'aligner', label: 'Gouttière'),
                AppDropdownOption(value: 'veneer', label: 'Facette'),
                AppDropdownOption(value: 'denture', label: 'Prothèse amovible'),
                AppDropdownOption(value: 'other', label: 'Autre'),
              ],
              onChanged: (v) {
                setState(() => _workType = v ?? 'crown');
                _saveDraft();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppDatePicker(
              label: 'Date d\'empreinte *',
              value: _impressionDate,
              lastDate: DateTime.now(),
              onChanged: (d) {
                setState(() => _impressionDate = d);
                _saveDraft();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _loadingPractitioners
                ? const LoadingView()
                : _practitionersError != null
                    ? ErrorView(
                        message: _practitionersError!,
                        onRetry: _loadPractitioners,
                      )
                    : SearchablePickerField(
                        key: const Key('prosthetic-practitioner-picker'),
                        label: 'Praticien *',
                        hint: 'Choisir un praticien',
                        value: _practitionerId,
                        options: [
                          for (final p in _practitioners)
                            PickerOption(id: p.id, label: p.name),
                        ],
                        onChanged: (v) {
                          setState(() => _practitionerId = v);
                          _saveDraft();
                        },
                      ),
            const SizedBox(height: AppSpacing.md),
            _loadingLabs
                ? const LoadingView()
                : _labsError != null
                    ? ErrorView(
                        message: _labsError!, onRetry: _loadLaboratories)
                    : SearchablePickerField(
                        key: const Key('prosthetic-laboratory-picker'),
                        label: 'Laboratoire',
                        hint: 'Aucun laboratoire',
                        clearLabel: 'Aucun laboratoire',
                        value: _laboratoryId,
                        // Only active laboratories: an archived one is never
                        // offered for a new case.
                        options: [
                          for (final l in _laboratories)
                            PickerOption(id: l.id, label: l.name),
                        ],
                        onChanged: (v) {
                          setState(() => _laboratoryId = v);
                          _saveDraft();
                        },
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
              label: 'Créer le dossier',
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientPickerSheet extends StatefulWidget {
  const _PatientPickerSheet();

  @override
  State<_PatientPickerSheet> createState() => _PatientPickerSheetState();
}

class _PatientPickerSheetState extends State<_PatientPickerSheet> {
  List<PatientData> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  int _searchGeneration = 0;

  Future<void> _search(String query) async {
    // A slow answer for "ab" must not replace the list for "abc".
    final generation = ++_searchGeneration;
    setState(() => _loading = true);
    try {
      final results = await getIt<PatientRepository>().search(query);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() => _loading = false);
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
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sélectionner un patient',
                style: AppTypography.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            AppSearchField(
              hint: 'Rechercher par référence...',
              onChanged: _search,
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(child: Text('Aucun patient trouvé.'))
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final p = _results[index];
                            return ListTile(
                              leading: CircleAvatar(child: Text(p.initials)),
                              title: Text(p.reference),
                              onTap: () => Navigator.of(context).pop(p),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
