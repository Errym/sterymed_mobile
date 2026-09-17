import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../data/models/patient_create_request.dart';
import '../bloc/patient_list_bloc.dart';

class PatientCreateSheet extends StatefulWidget {
  const PatientCreateSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<PatientListBloc>(),
        child: const PatientCreateSheet(),
      ),
    );
  }

  @override
  State<PatientCreateSheet> createState() => _PatientCreateSheetState();
}

class _PatientCreateSheetState extends State<PatientCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _refCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<PatientListBloc>().add(CreatePatient(PatientCreateRequest(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        )));
    AppSnackbar.show(context, 'Patient enregistré.', kind: SnackKind.success);
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
            const Text('Nouveau patient', style: AppTypography.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Prénom *',
              controller: _firstNameCtrl,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Nom *',
              controller: _lastNameCtrl,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Référence dossier',
              controller: _refCtrl,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Téléphone',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'E-mail',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: 'Enregistrer le patient', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
