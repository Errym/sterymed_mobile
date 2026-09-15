import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';

class RegisterForm extends StatefulWidget {
  final bool isLoading;
  final void Function({
    required String tenantName,
    required String tenantSlug,
    required String ownerName,
    required String ownerEmail,
    required String password,
  }) onSubmit;

  const RegisterForm({
    super.key,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _tenantNameCtrl = TextEditingController();
  final _tenantSlugCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _tenantNameCtrl.dispose();
    _tenantSlugCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validateSlug(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'L\'identifiant est obligatoire.';
    }
    final slug = value.trim();
    if (!RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(slug)) {
      return 'Utilisez uniquement des minuscules, chiffres et tirets.';
    }
    if (slug.length > 63) {
      return 'Maximum 63 caractères.';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(
      tenantName: _tenantNameCtrl.text.trim(),
      tenantSlug: _tenantSlugCtrl.text.trim(),
      ownerName: _ownerNameCtrl.text.trim(),
      ownerEmail: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Nom du cabinet',
            hint: 'ex. Cabinet Martin',
            controller: _tenantNameCtrl,
            validator: (v) => Validators.required(v, field: 'Le nom'),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Identifiant du cabinet',
            hint: 'ex. cabinet-martin',
            controller: _tenantSlugCtrl,
            validator: _validateSlug,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Votre nom complet',
            hint: 'ex. Dr. Jean Dupont',
            controller: _ownerNameCtrl,
            validator: (v) => Validators.required(v, field: 'Le nom'),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Adresse e-mail',
            hint: 'vous@cabinet.fr',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Mot de passe',
            hint: '8 caractères minimum',
            controller: _passwordCtrl,
            obscureText: _obscure,
            validator: Validators.password,
            suffix: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Créer le cabinet',
            isLoading: widget.isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
