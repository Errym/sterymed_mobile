import 'package:flutter/material.dart';

import '../../../../core/utils/formatters/date_formatter.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_date_picker.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../data/repositories/maintenance_record_repository.dart';
import '../../../../core/utils/error_message.dart';

/// Records-only — the backend exposes no update/delete route for
/// maintenance records, so unlike `ProgrammeFormSheet` this sheet only
/// ever creates.
class MaintenanceRecordFormSheet extends StatefulWidget {
  final String deviceId;
  const MaintenanceRecordFormSheet({super.key, required this.deviceId});

  static Future<bool?> show(BuildContext context, {required String deviceId}) {
    return showAppSheet<bool>(
      context,
      builder: (_) => MaintenanceRecordFormSheet(deviceId: deviceId),
    );
  }

  @override
  State<MaintenanceRecordFormSheet> createState() =>
      _MaintenanceRecordFormSheetState();
}

class _MaintenanceRecordFormSheetState
    extends State<MaintenanceRecordFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _technicianCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  // Backend enum App\Domain\Equipment\Enums\MaintenanceKind.
  String _kind = 'preventive';
  DateTime _performedAt = DateTime.now();
  DateTime? _nextDueAt;
  bool _submitting = false;

  @override
  void dispose() {
    _technicianCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nextDueAt != null && !_nextDueAt!.isAfter(_performedAt)) {
      AppSnackbar.show(
        context,
        'La prochaine échéance doit être postérieure à la date de '
        'l\'intervention.',
        kind: SnackKind.warning,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await getIt<MaintenanceRecordRepository>().create(
        deviceId: widget.deviceId,
        kind: _kind,
        technician: _technicianCtrl.text.trim(),
        performedAt: _performedAt,
        nextDueAt: _nextDueAt,
        description: _descriptionCtrl.text.trim(),
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Intervention enregistrée.',
          kind: SnackKind.success);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _kindLabel => switch (_kind) {
        'corrective' => 'Maintenance corrective',
        'calibration' => 'Étalonnage',
        _ => 'Maintenance préventive',
      };

  /// What will be written in the device's history, as it will read.
  Widget _preview() {
    final due = _nextDueAt;
    return PreviewCard(
      key: const Key('maintenance-preview'),
      mark: const EntityMark.icon(Icons.build_outlined),
      eyebrow: 'DOSSIER DE MAINTENANCE',
      title: _kindLabel,
      tags: [
        InfoTag(
          AppDateFormatter.date(_performedAt),
          icon: Icons.event_available_outlined,
        ),
        if (_technicianCtrl.text.trim().isNotEmpty)
          InfoTag(_technicianCtrl.text.trim(), icon: Icons.engineering_outlined),
        if (due != null)
          InfoTag(
            'Prochaine : ${AppDateFormatter.date(due)}',
            icon: Icons.schedule,
            color: AppColors.brandPrimary,
          ),
      ],
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
                  const Text(
                    'Nouvelle intervention de maintenance',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Chaque intervention reste dans l\'historique de '
                    'l\'appareil et sert de preuve en cas de contrôle.',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _preview(),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Intervention',
                    trailing:
                        const Text('Requis', style: AppTypography.caption),
                    children: [
                      AppDropdown<String>(
                        label: 'Type *',
                        value: _kind,
                        options: const [
                          AppDropdownOption(
                              value: 'preventive', label: 'Préventive'),
                          AppDropdownOption(
                              value: 'corrective', label: 'Corrective'),
                          AppDropdownOption(
                              value: 'calibration', label: 'Étalonnage'),
                        ],
                        onChanged: (v) =>
                            setState(() => _kind = v ?? 'preventive'),
                      ),
                      AppDatePicker(
                        label: 'Date de l\'intervention *',
                        value: _performedAt,
                        lastDate: DateTime.now(),
                        onChanged: (d) => setState(() => _performedAt = d),
                      ),
                      AppTextField(
                        label: 'Technicien',
                        hint: 'Ex : SAV Melag, technicien interne...',
                        controller: _technicianCtrl,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Suite',
                    trailing:
                        const Text('Facultatif', style: AppTypography.caption),
                    children: [
                      AppDatePicker(
                        label: 'Prochaine échéance (optionnel)',
                        value: _nextDueAt,
                        firstDate: _performedAt,
                        onChanged: (d) => setState(() => _nextDueAt = d),
                      ),
                      AppTextArea(
                        label: 'Description',
                        hint:
                            'Pièces remplacées, résultat du test, observations...',
                        controller: _descriptionCtrl,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PinnedFooter(
              child: PrimaryButton(
                label: 'Enregistrer l\'intervention',
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
