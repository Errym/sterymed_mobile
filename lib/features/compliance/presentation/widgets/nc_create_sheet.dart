import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../cycles/data/models/cycle_data.dart';
import '../../../cycles/data/repositories/cycle_repository.dart';
import '../../../labels/data/repositories/label_repository.dart';
import '../../data/repositories/non_conformity_repository.dart';
import '../../../../core/utils/error_message.dart';

class NcCreateSheet extends StatefulWidget {
  const NcCreateSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showAppSheet<bool>(
      context,
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

  final _cycleSearchCtrl = TextEditingController();
  List<CycleData> _cycles = [];
  String? _cycleCursor;
  bool _loadingMoreCycles = false;
  String _cycleQuery = '';
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
    _cycleSearchCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCycles() async {
    try {
      final page = await getIt<CycleRepository>().list(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _cycles = page.items;
        _cycleCursor = page.nextCursor;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Cycles older than the first page are reachable: the picker pages on
  /// demand instead of silently stopping at the 20 most recent.
  Future<void> _loadOlderCycles() async {
    final cursor = _cycleCursor;
    if (cursor == null || _loadingMoreCycles) return;
    setState(() => _loadingMoreCycles = true);
    try {
      final page = await getIt<CycleRepository>().loadMore(cursor);
      if (!mounted) return;
      setState(() {
        _cycles = [..._cycles, ...page.items];
        _cycleCursor = page.nextCursor;
        _loadingMoreCycles = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMoreCycles = false);
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  List<CycleData> get _visibleCycles {
    final q = _cycleQuery.trim().toLowerCase();
    if (q.isEmpty) return _cycles;
    return _cycles
        .where(
          (c) =>
              c.number.toLowerCase().contains(q) ||
              c.deviceName.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    String? subjectId;

    if (_subjectType == 'cycle') {
      subjectId = _cycleId;
      if (subjectId == null) {
        AppSnackbar.show(
          context,
          'Sélectionnez un cycle.',
          kind: SnackKind.warning,
        );
        return;
      }
    } else {
      // The code carries the label id; no lookup needed (and a recalled or
      // expired label, whose lookup is refused, can still be reported).
      final code = _labelCodeCtrl.text.trim();
      if (code.isEmpty) {
        AppSnackbar.show(
          context,
          'Saisissez un code d\'étiquette.',
          kind: SnackKind.warning,
        );
        return;
      }
      subjectId = LabelRepository.idFromCode(code);
      if (subjectId == null) {
        setState(() => _submitting = true);
        try {
          subjectId = (await getIt<LabelRepository>().getByCode(code)).labelId;
        } catch (e) {
          if (!mounted) return;
          AppSnackbar.show(
            context,
            ErrorMessage.from(e),
            kind: SnackKind.error,
          );
          setState(() => _submitting = false);
          return;
        }
      }
    }

    // Raising it is not a note: the server recalls the labels and quarantines
    // their batches. Say so before doing it.
    if (!mounted) return;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Déclarer cette non-conformité ?',
      message: _subjectType == 'cycle'
          ? 'Toutes les étiquettes déjà générées pour ce cycle seront '
                'rappelées (refusées au scan) et les lots concernés mis en '
                'quarantaine. Cette action ne peut pas être annulée depuis '
                'l\'application.'
          : 'Cette étiquette sera rappelée (refusée au scan) et son lot mis '
                'en quarantaine. Cette action ne peut pas être annulée depuis '
                'l\'application.',
      confirmLabel: 'Déclarer',
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      setState(() => _submitting = false);
      return;
    }

    setState(() => _submitting = true);
    try {
      await getIt<NonConformityRepository>().create(
        subjectType: _subjectType,
        subjectId: subjectId,
        description: _descriptionCtrl.text.trim(),
      );
      if (!mounted) return;
      AppSnackbar.show(
        context,
        _subjectType == 'cycle'
            ? 'Non-conformité enregistrée. Les étiquettes du cycle sont '
                  'rappelées.'
            : 'Non-conformité enregistrée. L\'étiquette est rappelée.',
        kind: SnackKind.success,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// What raising this will do, said before it is done.
  Widget _impact() {
    final isCycle = _subjectType == 'cycle';
    return Container(
      key: const Key('nc-impact'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_outlined, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cette déclaration a des effets immédiats',
                  style: AppTypography.bodyStrong
                      .copyWith(color: AppColors.danger),
                ),
                const SizedBox(height: 2),
                Text(
                  isCycle
                      ? 'Les étiquettes du cycle seront rappelées (refusées '
                          'au scan) et les lots concernés mis en quarantaine.'
                      : 'L\'étiquette sera rappelée (refusée au scan) et son '
                          'lot mis en quarantaine.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subjectPicker() {
    if (_subjectType != 'cycle') {
      return AppTextField(
        label: 'Code d\'étiquette *',
        hint: 'Scannez ou saisissez le code',
        controller: _labelCodeCtrl,
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis.' : null,
      );
    }
    if (_cycles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: const Text(
          'Aucun cycle disponible. Créez un cycle d\'abord.',
          style: AppTypography.caption,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Rechercher un cycle',
          hint: 'N° de cycle ou appareil',
          controller: _cycleSearchCtrl,
          onChanged: (v) => setState(() => _cycleQuery = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppDropdown<String>(
          label: 'Cycle concerné *',
          value: _visibleCycles.any((c) => c.id == _cycleId) ? _cycleId : null,
          options: _visibleCycles
              .map(
                (c) => AppDropdownOption(
                  value: c.id,
                  label: 'Cycle ${c.number} · ${c.deviceName}',
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _cycleId = v),
        ),
        if (_cycleCursor != null)
          TextButton(
            onPressed: _loadingMoreCycles ? null : _loadOlderCycles,
            child: Text(
              _loadingMoreCycles
                  ? 'Chargement…'
                  : 'Charger les cycles plus anciens',
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                children: [
                  const SheetHandle(),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Nouvelle non-conformité',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Signalez un incident sur un cycle de stérilisation ou '
                    'une étiquette.',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _impact(),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Sujet',
                    trailing:
                        const Text('Requis', style: AppTypography.caption),
                    children: [
                      AppDropdown<String>(
                        label: 'Type de sujet',
                        value: _subjectType,
                        options: const [
                          AppDropdownOption(value: 'cycle', label: 'Cycle'),
                          AppDropdownOption(
                              value: 'label', label: 'Étiquette'),
                        ],
                        onChanged: (v) =>
                            setState(() => _subjectType = v ?? 'cycle'),
                      ),
                      _subjectPicker(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Description',
                    trailing:
                        const Text('Requis', style: AppTypography.caption),
                    children: [
                      ReasonPresetChips(
                        controller: _descriptionCtrl,
                        presets: const [
                          'Test de contrôle non conforme',
                          'Paramètres hors tolérance',
                          'Emballage endommagé',
                          'Étiquette illisible',
                        ],
                      ),
                      AppTextArea(
                        label: 'Description *',
                        controller: _descriptionCtrl,
                        maxLines: 4,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PinnedFooter(
              child: PrimaryButton(
                label: 'Enregistrer la non-conformité',
                isLoading: _submitting,
                onPressed: (_subjectType == 'cycle' && _cycles.isEmpty)
                    ? null
                    : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
