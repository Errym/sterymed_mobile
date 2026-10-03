import 'package:flutter/material.dart';

import '../../../../core/utils/formatters/date_formatter.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../data/models/dlu_rule_data.dart';
import '../../data/repositories/dlu_repository.dart';

class DluRuleFormSheet extends StatefulWidget {
  final DluRuleData? existing;
  const DluRuleFormSheet({super.key, this.existing});

  static Future<bool?> show(BuildContext context, {DluRuleData? existing}) {
    return showAppSheet<bool>(
      context,
      builder: (_) => DluRuleFormSheet(existing: existing),
    );
  }

  @override
  State<DluRuleFormSheet> createState() => _DluRuleFormSheetState();
}

class _DluRuleFormSheetState extends State<DluRuleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _packagingCtrl;
  late final TextEditingController _storageCtrl;
  late final TextEditingController _shelfLifeCtrl;
  late final TextEditingController _reasonCtrl;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _packagingCtrl =
        TextEditingController(text: widget.existing?.packagingType ?? '');
    _storageCtrl =
        TextEditingController(text: widget.existing?.storageCondition ?? '');
    _shelfLifeCtrl = TextEditingController(
        text: widget.existing?.shelfLifeDays.toString() ?? '');
    _reasonCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _packagingCtrl.dispose();
    _storageCtrl.dispose();
    _shelfLifeCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final repo = getIt<DluRepository>();
      if (_isEdit) {
        await repo.update(
          widget.existing!.id,
          packagingType: _packagingCtrl.text.trim(),
          storageCondition: _storageCtrl.text.trim(),
          shelfLifeDays: int.parse(_shelfLifeCtrl.text.trim()),
          reason: _reasonCtrl.text.trim(),
        );
      } else {
        await repo.create(
          packagingType: _packagingCtrl.text.trim(),
          storageCondition: _storageCtrl.text.trim(),
          shelfLifeDays: int.parse(_shelfLifeCtrl.text.trim()),
          reason: _reasonCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      AppSnackbar.show(context, 'Règle DLU enregistrée.',
          kind: SnackKind.success);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// The rule as it will read on a label: what is stored how, for how long, and
  /// until which date a pouch sterilised today would be usable.
  Widget _preview() {
    return ListenableBuilder(
      listenable: Listenable.merge(
        [_packagingCtrl, _storageCtrl, _shelfLifeCtrl],
      ),
      builder: (context, _) {
        final pack = _packagingCtrl.text.trim();
        final storage = _storageCtrl.text.trim();
        final days = int.tryParse(_shelfLifeCtrl.text.trim());
        final until = (days != null && days > 0)
            ? DateTime.now().add(Duration(days: days))
            : null;
        return PreviewCard(
          key: const Key('dlu-preview'),
          mark: const EntityMark.icon(Icons.timer_outlined),
          eyebrow: 'RÈGLE DLU',
          title: (pack.isEmpty && storage.isEmpty)
              ? 'Conditionnement · Stockage'
              : '${pack.isEmpty ? '…' : pack} · ${storage.isEmpty ? '…' : storage}',
          titleIsPlaceholder: pack.isEmpty && storage.isEmpty,
          tags: [
            if (days != null && days > 0)
              InfoTag('$days jours', icon: Icons.timelapse),
            if (until != null)
              InfoTag(
                'Stérilisé aujourd\'hui : utilisable jusqu\'au '
                '${AppDateFormatter.date(until)}',
                icon: Icons.event_available_outlined,
                color: AppColors.brandPrimary,
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final affected = widget.existing?.existingLabelsCount ?? 0;
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
                  Text(
                    _isEdit ? 'Modifier la règle DLU' : 'Nouvelle règle DLU',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'La durée limite d\'utilisation fixe la date de péremption '
                    'imprimée sur chaque étiquette de ce conditionnement.',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _preview(),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Règle',
                    trailing:
                        const Text('Requis', style: AppTypography.caption),
                    children: [
                      AppTextField(
                        label: 'Type de conditionnement *',
                        controller: _packagingCtrl,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                      ),
                      AppTextField(
                        label: 'Condition de stockage *',
                        controller: _storageCtrl,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                      ),
                      AppTextField(
                        label: 'Durée de vie (jours) *',
                        controller: _shelfLifeCtrl,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n < 1) {
                            return 'Nombre de jours invalide.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  if (_isEdit && affected > 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                      child: Text(
                        '$affected étiquette(s) existante(s) utilisent déjà '
                        'cette règle. Cette modification ne change pas leur '
                        'date de péremption déjà calculée, seulement les '
                        'prochaines.',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Justification',
                    trailing:
                        const Text('Requis', style: AppTypography.caption),
                    children: [
                      AppTextField(
                        label: 'Motif de la modification *',
                        controller: _reasonCtrl,
                        maxLines: 2,
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
                label: _isEdit
                    ? 'Enregistrer les modifications'
                    : 'Enregistrer la règle',
                onPressed: _submitting ? null : _submit,
                isLoading: _submitting,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
