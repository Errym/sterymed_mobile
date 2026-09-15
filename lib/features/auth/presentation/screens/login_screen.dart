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
import '../widgets/login_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.xxl * 2,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.xxxl),
                        const Center(child: AppLogo(height: 56)),
                        const SizedBox(height: AppSpacing.xxxl),
                        Text('Bienvenue', style: AppTypography.pageTitle),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Connectez-vous pour accéder à votre espace cabinet.',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            final isLoading = state is AuthLoading;
                            return LoginForm(
                              isLoading: isLoading,
                              onSubmit: ({
                                required String tenantSlug,
                                required String email,
                                required String password,
                              }) {
                                context.read<AuthBloc>().add(
                                      AuthLoginSubmitted(
                                        tenantSlug: tenantSlug,
                                        email: email,
                                        password: password,
                                      ),
                                    );
                              },
                            );
                          },
                        ),
                        const Spacer(),
                        const SizedBox(height: AppSpacing.xxl),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Pas encore de compte ? ',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.go(Routes.register),
                              child: Text(
                                'Créer un cabinet',
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
              );
            },
          ),
        ),
      ),
    );
  }
}
