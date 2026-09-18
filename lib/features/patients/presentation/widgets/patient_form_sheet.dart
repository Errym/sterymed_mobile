import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../data/models/patient_create_request.dart';
import '../../data/models/patient_data.dart';
import '../bloc/patient_list_bloc.dart';

class PatientFormSheet extends StatefulWidget {
  final PatientData? existing;

  const PatientFormSheet({super.key, this.existing});

  static Future<bool?> show(BuildContext context, {PatientData? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<PatientListBloc>(),
        child: PatientFormSheet(existing: existing),
      ),
    );
  }

  @override
  State<PatientFormSheet> createState() => _PatientFormSheetState();
}

class _PatientFormSheetState extends State<PatientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _refCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.existing?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: widget.existing?.lastName ?? '');
    _refCtrl = TextEditingController(text: widget.existing?.reference ?? '');
    _phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.existing?.email ?? '');
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _refCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final req = PatientCreateRequest(
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
    );

    if (_isEdit) {
      context.read<PatientListBloc>().add(
            UpdatePatient(id: widget.existing!.id, request: req),
          );
    } else {
      context.read<PatientListBloc>().add(CreatePatient(req));
    }

    if (!mounted) return;
    AppSnackbar.show(
      context,
      _isEdit ? 'Patient modifié.' : 'Patient enregistré.',
      kind: SnackKind.success,
    );
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
            Text(
              _isEdit ? 'Modifier le patient' : 'Nouveau patient',
              style: AppTypography.sectionTitle,
            ),
            if (_isEdit) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Le dossier sera recréé avec un nouvel identifiant '
                        'interne (limitation du serveur actuel).',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Prénom *',
              controller: _firstNameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Nom *',
              controller: _lastNameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
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
            PrimaryButton(
              label: _isEdit ? 'Enregistrer les modifications' : 'Enregistrer',
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
