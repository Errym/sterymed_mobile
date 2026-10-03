import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';

class LoginForm extends StatefulWidget {
  final bool isLoading;
  final void Function({
    required String tenantSlug,
    required String email,
    required String password,
  })
  onSubmit;

  const LoginForm({super.key, required this.isLoading, required this.onSubmit});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _tenantCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _tenantCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(
      tenantSlug: _tenantCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
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
            label: 'Identifiant du cabinet',
            hint: 'ex. cabinet-martin',
            controller: _tenantCtrl,
            prefix: const Icon(Icons.apartment_outlined, size: 20),
            validator: (v) => Validators.required(v, field: 'L\'identifiant'),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Adresse e-mail',
            hint: 'vous@cabinet.fr',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            prefix: const Icon(Icons.mail_outline, size: 20),
            validator: Validators.email,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Mot de passe',
            hint: '••••••••',
            controller: _passwordCtrl,
            obscureText: _obscure,
            prefix: const Icon(Icons.lock_outline, size: 20),
            validator: Validators.password,
            suffix: IconButton(
              tooltip: _obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go(Routes.forgotPassword),
              child: const Text('Mot de passe oublié ?'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          PrimaryButton(
            label: 'Se connecter',
            isLoading: widget.isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
