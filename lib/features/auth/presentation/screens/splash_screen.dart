import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/misc/app_logo.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _minimumSplashDuration = Duration(milliseconds: 1500);

  bool _hasFiredSessionCheck = false;
  bool _hasNavigated = false;
  bool _minimumElapsed = false;
  AuthState? _pendingState;

  @override
  void initState() {
    super.initState();

    Future<void>.delayed(_minimumSplashDuration, () {
      if (!mounted) return;
      _minimumElapsed = true;
      final pending = _pendingState;
      if (pending != null) {
        _navigate(pending);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasFiredSessionCheck) return;
      _hasFiredSessionCheck = true;
      context.read<AuthBloc>().add(const AuthSessionChecked());
    });
  }

  void _navigate(AuthState state) {
    if (!mounted || _hasNavigated) return;

    if (state is AuthAuthenticated) {
      _hasNavigated = true;
      context.go(Routes.dashboard);
    } else if (state is AuthUnauthenticated) {
      _hasNavigated = true;
      context.go(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading || state is AuthInitial) return;

        if (_minimumElapsed) {
          _navigate(state);
        } else {
          _pendingState = state;
        }
      },
      child: const Scaffold(
        backgroundColor: AppColors.backgroundApp,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogo(height: 56),
              SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.brandPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
