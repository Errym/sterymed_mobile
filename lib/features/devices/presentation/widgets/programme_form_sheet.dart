import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../cycles/data/models/device_program_data.dart';
import '../../../cycles/data/repositories/device_program_repository.dart';
import '../../../../core/utils/error_message.dart';

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
    return showAppSheet<bool>(
      context,
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
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Usual sterilization cycles, to fill the two parameters in one tap. The
  /// person can still change either number afterwards.
  static const _presets = <(String, int, int)>[
    ('Instruments emballés', 134, 4),
    ('Prions', 134, 18),
    ('Textiles, délicat', 121, 20),
  ];

  Widget _preview() {
    return ListenableBuilder(
      listenable: Listenable.merge([_nameCtrl, _tempCtrl, _minuteCtrl]),
      builder: (context, _) {
        final name = _nameCtrl.text.trim();
        final temp = int.tryParse(_tempCtrl.text.trim());
        final minutes = int.tryParse(_minuteCtrl.text.trim());
        return PreviewCard(
          key: const Key('programme-preview'),
          mark: const EntityMark.icon(Icons.thermostat_outlined),
          eyebrow: 'PROGRAMME DE STÉRILISATION',
          title: name.isEmpty ? 'Nom du programme' : name,
          titleIsPlaceholder: name.isEmpty,
          tags: [
            if (temp != null) InfoTag('$temp °C', icon: Icons.thermostat),
            if (minutes != null) InfoTag('$minutes min', icon: Icons.timer_outlined),
            InfoTag(
              _active ? 'Actif' : 'Inactif',
              icon: _active ? Icons.check_circle_outline : Icons.pause_circle_outline,
              color: _active ? AppColors.success : AppColors.textSecondary,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    _isEdit
                        ? 'Modifier le programme'
                        : 'Nouveau programme de stérilisation',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'La température et la durée de plateau sont reprises sur '
                    'chaque cycle lancé avec ce programme.',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _preview(),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Programme',
                    trailing:
                        const Text('Requis', style: AppTypography.caption),
                    children: [
                      AppTextField(
                        label: 'Nom du programme *',
                        hint: 'Ex : Instrument 134C 4min',
                        controller: _nameCtrl,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Paramètres',
                    trailing:
                        const Text('Requis', style: AppTypography.caption),
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final (label, temp, minutes) in _presets)
                            ActionChip(
                              key: ValueKey('preset_${temp}_$minutes'),
                              label: Text('$label · $temp °C · $minutes min'),
                              labelStyle: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              backgroundColor: AppColors.surfaceWell,
                              side: BorderSide.none,
                              onPressed: () {
                                _tempCtrl.text = '$temp';
                                _minuteCtrl.text = '$minutes';
                                if (_nameCtrl.text.trim().isEmpty) {
                                  _nameCtrl.text = '$label $temp°C';
                                }
                              },
                            ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Disponibilité',
                    children: [
                      SwitchListTile(
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                        title: const Text('Actif', style: AppTypography.body),
                        subtitle: const Text(
                          'Un programme inactif n\'est plus proposé pour un '
                          'nouveau cycle.',
                          style: AppTypography.caption,
                        ),
                        contentPadding: EdgeInsets.zero,
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
                    : 'Ajouter le programme',
                isLoading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
