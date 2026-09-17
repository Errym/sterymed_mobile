import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../data/datasources/location_remote_datasource.dart';

class LocationFormSheet extends StatefulWidget {
  final String siteId;
  const LocationFormSheet({super.key, required this.siteId});

  static Future<bool?> show(BuildContext context, {required String siteId}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => LocationFormSheet(siteId: siteId),
    );
  }

  @override
  State<LocationFormSheet> createState() => _LocationFormSheetState();
}

class _LocationFormSheetState extends State<LocationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _kind = 'room';
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await getIt<LocationRemoteDatasource>().create(
        siteId: widget.siteId,
        name: _nameCtrl.text.trim(),
        kind: _kind,
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Emplacement enregistré.',
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
            const Text('Nouvel emplacement',
                style: AppTypography.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Nom *',
              hint: 'Salle de stérilisation',
              controller: _nameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String>(
              label: 'Type',
              value: _kind,
              options: const [
                AppDropdownOption(value: 'room', label: 'Salle'),
                AppDropdownOption(value: 'chair', label: 'Fauteuil'),
                AppDropdownOption(value: 'storage', label: 'Stockage'),
                AppDropdownOption(value: 'sterilization', label: 'Stérilisation'),
              ],
              onChanged: (v) => setState(() => _kind = v ?? 'room'),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Enregistrer l\'emplacement',
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
