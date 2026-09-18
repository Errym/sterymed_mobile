import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../cycles/data/models/device_program_data.dart';
import '../../../cycles/data/repositories/device_program_repository.dart';

class ProgrammeFormSheet extends StatefulWidget {
  final String deviceId;
  final DeviceProgramData? existing;

  const ProgrammeFormSheet({
    super.key,
    required this.deviceId,
    this.existing,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String deviceId,
    DeviceProgramData? existing,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => ProgrammeFormSheet(
        deviceId: deviceId,
        existing: existing,
      ),
    );
  }

  @override
  State<ProgrammeFormSheet> createState() => _ProgrammeFormSheetState();
}

class _ProgrammeFormSheetState extends State<ProgrammeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _tempCtrl;
  late final TextEditingController _minuteCtrl;
  bool _active = true;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _tempCtrl = TextEditingController(
      text: widget.existing?.temperatureCelsius.toString() ?? '134',
    );
    _minuteCtrl = TextEditingController(
      text: widget.existing?.plateauMinutes.toString() ?? '4',
    );
    _active = widget.existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tempCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final repo = getIt<DeviceProgramRepository>();
      if (_isEdit) {
        await repo.update(
          deviceId: widget.deviceId,
          programId: widget.existing!.id,
          name: _nameCtrl.text.trim(),
          temperatureCelsius: int.parse(_tempCtrl.text.trim()),
          plateauMinutes: int.parse(_minuteCtrl.text.trim()),
          isActive: _active,
        );
      } else {
        await repo.create(
          deviceId: widget.deviceId,
          name: _nameCtrl.text.trim(),
          temperatureCelsius: int.parse(_tempCtrl.text.trim()),
          plateauMinutes: int.parse(_minuteCtrl.text.trim()),
          isActive: _active,
        );
      }
      if (!mounted) return;
      AppSnackbar.show(
        context,
        _isEdit ? 'Programme modifié.' : 'Programme ajouté.',
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
              _isEdit
                  ? 'Modifier le programme'
                  : 'Nouveau programme de stérilisation',
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Nom du programme *',
              hint: 'Ex : Instrument 134C 4min',
              controller: _nameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Température (°C) *',
                    controller: _tempCtrl,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 100 || n > 200) {
                        return '100–200';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: 'Plateau (min) *',
                    controller: _minuteCtrl,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 1 || n > 180) {
                        return '1–180';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('Actif', style: AppTypography.body),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: _isEdit
                  ? 'Enregistrer les modifications'
                  : 'Ajouter le programme',
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
