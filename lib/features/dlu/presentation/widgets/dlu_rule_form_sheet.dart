import 'package:flutter/material.dart';

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
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              _isEdit ? 'Modifier la règle DLU' : 'Nouvelle règle DLU',
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Type de conditionnement *',
              controller: _packagingCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Condition de stockage *',
              controller: _storageCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Durée de vie (jours) *',
              controller: _shelfLifeCtrl,
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 1) return 'Nombre de jours invalide.';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            if (_isEdit && widget.existing!.existingLabelsCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Text(
                  '${widget.existing!.existingLabelsCount} étiquette(s) '
                  'existante(s) utilisent déjà cette règle. Cette '
                  'modification ne change pas leur date de péremption déjà '
                  'calculée, seulement les prochaines.',
                  style: AppTypography.caption.copyWith(color: AppColors.warning),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppTextField(
              label: 'Motif de la modification *',
              controller: _reasonCtrl,
              maxLines: 2,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: _isEdit
                  ? 'Enregistrer les modifications'
                  : 'Enregistrer la règle',
              onPressed: _submit,
              isLoading: _submitting,
            ),
          ],
        ),
      ),
    );
  }
}
