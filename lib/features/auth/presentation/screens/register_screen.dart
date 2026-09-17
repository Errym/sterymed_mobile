import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/misc/app_logo.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/register_form.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: SafeArea(
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthError) {
              AppSnackbar.show(
                context,
                state.exception.message,
                kind: SnackKind.error,
              );
            }
            if (state is AuthAuthenticated) {
              context.go(Routes.dashboard);
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go(Routes.login),
                      icon: const Icon(Icons.arrow_back),
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const Center(child: AppLogo(height: 48)),
                const SizedBox(height: AppSpacing.xxl),
                const Text(
                  'Créer votre cabinet',
                  style: AppTypography.pageTitle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Quelques informations et vous êtes prêt.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;
                    return RegisterForm(
                      isLoading: isLoading,
                      onSubmit: ({
                        required String tenantName,
                        required String tenantSlug,
                        required String ownerName,
                        required String ownerEmail,
                        required String password,
                      }) {
                        context.read<AuthBloc>().add(
                              AuthRegisterSubmitted(
                                tenantName: tenantName,
                                tenantSlug: tenantSlug,
                                ownerName: ownerName,
                                ownerEmail: ownerEmail,
                                password: password,
                              ),
                            );
                      },
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Vous avez déjà un compte ? ',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go(Routes.login),
                      child: Text(
                        'Se connecter',
                        style: AppTypography.bodyStrong.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
