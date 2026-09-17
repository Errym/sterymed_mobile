import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../bloc/site_list_bloc.dart';

class SiteFormSheet extends StatefulWidget {
  const SiteFormSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<SiteListBloc>(),
        child: const SiteFormSheet(),
      ),
    );
  }

  @override
  State<SiteFormSheet> createState() => _SiteFormSheetState();
}

class _SiteFormSheetState extends State<SiteFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  bool _isPrimary = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    // Fire-and-forget: the bloc handles the refresh.
    context.read<SiteListBloc>().add(CreateSite(
          name: _nameCtrl.text.trim(),
          addressLine1: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
          city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
          isPrimary: _isPrimary,
        ));

    // Snackbar + close immediately, list will refresh behind.
    AppSnackbar.show(context, 'Site enregistré.', kind: SnackKind.success);
    Navigator.of(context).pop(true);
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
            const Text('Nouveau site', style: AppTypography.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Nom du site *',
              hint: 'Cabinet Principal',
              controller: _nameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Adresse',
              hint: '14 Avenue de l\'Opéra',
              controller: _addressCtrl,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Ville',
              hint: 'Paris',
              controller: _cityCtrl,
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              value: _isPrimary,
              onChanged: (v) => setState(() => _isPrimary = v),
              title: const Text('Site principal', style: AppTypography.body),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Enregistrer le site',
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
