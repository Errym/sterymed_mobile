import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_date_picker.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../data/repositories/maintenance_record_repository.dart';

/// Records-only — the backend exposes no update/delete route for
/// maintenance records, so unlike `ProgrammeFormSheet` this sheet only
/// ever creates.
class MaintenanceRecordFormSheet extends StatefulWidget {
  final String deviceId;
  const MaintenanceRecordFormSheet({super.key, required this.deviceId});

  static Future<bool?> show(BuildContext context, {required String deviceId}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
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
            const Text(
              'Nouvelle intervention de maintenance',
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String>(
              label: 'Type *',
              value: _kind,
              options: const [
                AppDropdownOption(value: 'preventive', label: 'Préventive'),
                AppDropdownOption(value: 'corrective', label: 'Corrective'),
                AppDropdownOption(value: 'calibration', label: 'Étalonnage'),
              ],
              onChanged: (v) => setState(() => _kind = v ?? 'preventive'),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Technicien',
              hint: 'Ex : SAV Melag, technicien interne...',
              controller: _technicianCtrl,
            ),
            const SizedBox(height: AppSpacing.md),
            AppDatePicker(
              label: 'Date de l\'intervention *',
              value: _performedAt,
              lastDate: DateTime.now(),
              onChanged: (d) => setState(() => _performedAt = d),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDatePicker(
              label: 'Prochaine échéance (optionnel)',
              value: _nextDueAt,
              firstDate: _performedAt,
              onChanged: (d) => setState(() => _nextDueAt = d),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextArea(
              label: 'Description',
              hint: 'Pièces remplacées, résultat du test, observations...',
              controller: _descriptionCtrl,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Enregistrer l\'intervention',
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
