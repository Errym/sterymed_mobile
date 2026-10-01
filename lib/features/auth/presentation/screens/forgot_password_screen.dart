import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../bloc/forgot_password_bloc.dart';
import '../bloc/forgot_password_event.dart';
import '../bloc/forgot_password_state.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ForgotPasswordBloc>(
      create: (_) => getIt<ForgotPasswordBloc>(),
      child: const _ForgotPasswordView(),
    );
  }
}

class _ForgotPasswordView extends StatefulWidget {
  const _ForgotPasswordView();

  @override
  State<_ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<_ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ForgotPasswordBloc>().add(
      SubmitForgotPassword(email: _emailCtrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(
        title: 'Mot de passe oublié',
        showBack: true,
        navy: false,
      ),
      body: BlocConsumer<ForgotPasswordBloc, ForgotPasswordState>(
        listener: (context, state) {
          if (state is ForgotPasswordFailure) {
            AppSnackbar.show(context, state.message, kind: SnackKind.error);
          }
        },
        builder: (context, state) {
          if (state is ForgotPasswordSuccess) {
            return _SentPanel(
              email: _emailCtrl.text.trim(),
              onBack: () => context.go(Routes.login),
              // The form is not on screen here, so skip its validator: the
              // address was already validated when first submitted.
              onResend: () => context.read<ForgotPasswordBloc>().add(
                SubmitForgotPassword(email: _emailCtrl.text.trim()),
              ),
            );
          }
          return _buildForm(context, state);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, ForgotPasswordState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Réinitialiser votre mot de passe',
              style: AppTypography.pageTitle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Indiquez l\'adresse e-mail de votre compte. Nous vous '
              'enverrons un lien pour définir un nouveau mot de passe.',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppTextField(
              label: 'Adresse e-mail',
              hint: 'vous@cabinet.fr',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Envoyer le lien',
              isLoading: state is ForgotPasswordLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown after the request. The reset itself happens in the browser, so this
/// says exactly what to do next and offers a way back to the sign-in screen.
/// It never claims an account exists: the server answers the same either way.
class _SentPanel extends StatelessWidget {
  final String email;
  final VoidCallback onBack;
  final VoidCallback onResend;

  const _SentPanel({
    required this.email,
    required this.onBack,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.mark_email_read_outlined,
            size: 56,
            color: AppColors.brandPrimary,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Vérifiez votre boîte mail',
            style: AppTypography.pageTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Si un compte correspond à $email, un e-mail de réinitialisation '
            'vient d\'être envoyé.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            '1. Ouvrez l\'e-mail et touchez le lien.\n'
            '2. Choisissez un nouveau mot de passe dans le navigateur.\n'
            '3. Revenez ici et connectez-vous.',
            style: AppTypography.body,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Le lien expire au bout d\'un moment. Pensez à vérifier vos '
            'courriers indésirables.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(label: 'Retour à la connexion', onPressed: onBack),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onResend,
            child: const Text('Renvoyer l\'e-mail'),
          ),
        ],
      ),
    );
  }
}
