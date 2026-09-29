#!/usr/bin/env bash
source "$(dirname "$0")/../phase1/_common.sh"

banner "FIX 2.3 — Password reset flow"

require_repo_root
require_clean_tree

ENDPOINTS="lib/core/config/api_endpoints.dart"
REMOTE="lib/features/auth/data/datasources/auth_remote_datasource.dart"
REPO="lib/features/auth/data/repositories/auth_repository.dart"
BLOC="lib/features/auth/presentation/bloc/forgot_password_bloc.dart"
EVENT="lib/features/auth/presentation/bloc/forgot_password_event.dart"
STATE="lib/features/auth/presentation/bloc/forgot_password_state.dart"
SCREEN="lib/features/auth/presentation/screens/forgot_password_screen.dart"
ROUTES="lib/core/router/routes.dart"
ROUTE_NAMES="lib/core/router/route_names.dart"
ROUTER="lib/core/router/app_router.dart"
LOGIN_FORM="lib/features/auth/presentation/widgets/login_form.dart"
DI="lib/di/features_di.dart"

# ── 1. Endpoints ──────────────────────────────────────────────────────
backup_file "$ENDPOINTS"
if grep -q "forgotPassword" "$ENDPOINTS"; then
  ok "Endpoints already defined"
else
  append_after "$ENDPOINTS" \
    "static const logout = '\$_v1/auth/logout';" \
    "  static const forgotPassword = '\$_v1/auth/forgot-password';
  static const resetPassword = '\$_v1/auth/reset-password';"
fi

# ── 2. Remote datasource ──────────────────────────────────────────────
backup_file "$REMOTE"
if grep -q "forgotPassword" "$REMOTE"; then
  ok "Remote datasource already has forgotPassword"
else
  python3 - "$REMOTE" <<'PYEOF'
import io, sys

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

method = '''
  Future<void> forgotPassword({
    required String tenantSlug,
    required String email,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.forgotPassword,
        data: {'tenant_slug': tenantSlug, 'email': email},
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
'''

# Insert before the register method.
anchor = "  Future<LoginResponse> register({"
if anchor not in src:
    print("Register method not found — insert forgotPassword manually", file=sys.stderr)
    sys.exit(1)
src = src.replace(anchor, method + "\n" + anchor, 1)

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Added forgotPassword to auth_remote_datasource")
PYEOF
fi

# ── 3. Repository ─────────────────────────────────────────────────────
backup_file "$REPO"
if grep -q "forgotPassword" "$REPO"; then
  ok "Repository already has forgotPassword"
else
  python3 - "$REPO" <<'PYEOF'
import io, sys

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

method = '''
  Future<void> forgotPassword({
    required String tenantSlug,
    required String email,
  }) =>
      _remote.forgotPassword(tenantSlug: tenantSlug, email: email);
'''

anchor = "  Future<void> logout() async {"
if anchor not in src:
    print("logout method not found", file=sys.stderr)
    sys.exit(1)
src = src.replace(anchor, method + "\n" + anchor, 1)

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Added forgotPassword to auth_repository")
PYEOF
fi

# ── 4. Bloc + Event + State (only if missing) ─────────────────────────
if [[ -f "$BLOC" && -f "$EVENT" && -f "$STATE" ]]; then
  ok "ForgotPassword bloc already exists — skipping creation"
else
  cat > "$BLOC" <<'DART'
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/utils/error_message.dart';
import '../../data/repositories/auth_repository.dart';
import 'forgot_password_event.dart';
import 'forgot_password_state.dart';

class ForgotPasswordBloc
    extends Bloc<ForgotPasswordEvent, ForgotPasswordState> {
  final AuthRepository _repository;

  ForgotPasswordBloc(this._repository) : super(const ForgotPasswordIdle()) {
    on<SubmitForgotPassword>(_onSubmit);
  }

  Future<void> _onSubmit(
    SubmitForgotPassword event,
    Emitter<ForgotPasswordState> emit,
  ) async {
    emit(const ForgotPasswordLoading());
    try {
      await _repository.forgotPassword(
        tenantSlug: event.tenantSlug,
        email: event.email,
      );
      emit(const ForgotPasswordSuccess());
    } on ApiException catch (e) {
      emit(ForgotPasswordFailure(ErrorMessage.from(e)));
    } catch (e) {
      emit(ForgotPasswordFailure(ErrorMessage.from(e)));
    }
  }
}
DART

  cat > "$EVENT" <<'DART'
import 'package:equatable/equatable.dart';

abstract class ForgotPasswordEvent extends Equatable {
  const ForgotPasswordEvent();

  @override
  List<Object?> get props => [];
}

class SubmitForgotPassword extends ForgotPasswordEvent {
  final String tenantSlug;
  final String email;

  const SubmitForgotPassword({
    required this.tenantSlug,
    required this.email,
  });

  @override
  List<Object?> get props => [tenantSlug, email];
}
DART

  cat > "$STATE" <<'DART'
import 'package:equatable/equatable.dart';

abstract class ForgotPasswordState extends Equatable {
  const ForgotPasswordState();

  @override
  List<Object?> get props => [];
}

class ForgotPasswordIdle extends ForgotPasswordState {
  const ForgotPasswordIdle();
}

class ForgotPasswordLoading extends ForgotPasswordState {
  const ForgotPasswordLoading();
}

class ForgotPasswordSuccess extends ForgotPasswordState {
  const ForgotPasswordSuccess();
}

class ForgotPasswordFailure extends ForgotPasswordState {
  final String message;

  const ForgotPasswordFailure(this.message);

  @override
  List<Object?> get props => [message];
}
DART
  ok "Created ForgotPassword bloc/event/state"
fi

# ── 5. Screen (only if missing) ──────────────────────────────────────
if [[ -f "$SCREEN" ]]; then
  ok "ForgotPassword screen already exists — skipping"
else
  mkdir -p "$(dirname "$SCREEN")"
  cat > "$SCREEN" <<'DART'
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
  final _tenantCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _tenantCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ForgotPasswordBloc>().add(
          SubmitForgotPassword(
            tenantSlug: _tenantCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
          ),
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
      body: BlocListener<ForgotPasswordBloc, ForgotPasswordState>(
        listener: (context, state) {
          if (state is ForgotPasswordSuccess) {
            AppSnackbar.show(
              context,
              'Si un compte correspond, un e-mail de réinitialisation a été '
              'envoyé.',
              kind: SnackKind.success,
            );
            context.go(Routes.login);
          }
          if (state is ForgotPasswordFailure) {
            AppSnackbar.show(context, state.message, kind: SnackKind.error);
          }
        },
        child: SingleChildScrollView(
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
                  'Indiquez l\'identifiant de votre cabinet et votre adresse '
                  'e-mail.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppTextField(
                  label: 'Identifiant du cabinet',
                  hint: 'ex. cabinet-martin',
                  controller: _tenantCtrl,
                  validator: (v) =>
                      Validators.required(v, field: 'L\'identifiant'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Adresse e-mail',
                  hint: 'vous@cabinet.fr',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: AppSpacing.xl),
                BlocBuilder<ForgotPasswordBloc, ForgotPasswordState>(
                  builder: (context, state) {
                    return PrimaryButton(
                      label: 'Envoyer le lien',
                      isLoading: state is ForgotPasswordLoading,
                      onPressed: _submit,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
DART
  ok "Created forgot_password_screen.dart"
fi

# ── 6. Routes + RouteNames ────────────────────────────────────────────
backup_file "$ROUTES"
if ! grep -q "forgotPassword" "$ROUTES"; then
  append_after "$ROUTES" \
    "static const register = '/register';" \
    "  static const forgotPassword = '/forgot-password';"
fi

backup_file "$ROUTE_NAMES"
if ! grep -q "forgotPassword" "$ROUTE_NAMES"; then
  append_after "$ROUTE_NAMES" \
    "static const register = 'register';" \
    "  static const forgotPassword = 'forgot-password';"
fi

# ── 7. Router ─────────────────────────────────────────────────────────
backup_file "$ROUTER"
ensure_import "$ROUTER" "import '../../features/auth/presentation/screens/forgot_password_screen.dart';"

python3 - "$ROUTER" <<'PYEOF'
import io, sys

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

# Add to public routes.
if "loc == Routes.forgotPassword" not in src:
    src = src.replace(
        "loc == Routes.register ||",
        "loc == Routes.register ||\n          loc == Routes.forgotPassword ||",
        1,
    )

# Add GoRoute after register route.
if "Routes.forgotPassword," not in src:
    anchor = """      GoRoute(
        path: Routes.register,
        name: RouteNames.register,
        pageBuilder: (_, s) => _fade(s, const RegisterScreen()),
      ),"""
    addition = anchor + """
      GoRoute(
        path: Routes.forgotPassword,
        name: RouteNames.forgotPassword,
        pageBuilder: (_, s) => _fade(s, const ForgotPasswordScreen()),
      ),"""
    src = src.replace(anchor, addition, 1)

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Patched app_router.dart")
PYEOF

# ── 8. Login form link ────────────────────────────────────────────────
backup_file "$LOGIN_FORM"
if grep -q "forgotPassword" "$LOGIN_FORM"; then
  ok "Login form already has forgot-password link"
else
  python3 - "$LOGIN_FORM" <<'PYEOF'
import io, sys

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

link_block = """          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go(Routes.forgotPassword),
              child: const Text('Mot de passe oublié ?'),
            ),
          ),
"""

anchor = """          const SizedBox(height: AppSpacing.xl),
          PrimaryButton("""

if anchor in src:
    src = src.replace(anchor, link_block + anchor, 1)

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Added forgot-password link to login_form")
PYEOF
fi

# ── 9. DI registration ────────────────────────────────────────────────
backup_file "$DI"
if ! grep -q "registerFactory<ForgotPasswordBloc>" "$DI"; then
  append_after "$DI" \
    "getIt.registerLazySingleton<AuthBloc>(() => AuthBloc(getIt<AuthRepository>()));" \
    "  getIt.registerFactory<ForgotPasswordBloc>(
    () => ForgotPasswordBloc(getIt<AuthRepository>()),
  );"
fi

run_analyze
run_tests
commit_fix "feat(auth): implement forgot password flow" \
  "$ENDPOINTS" "$REMOTE" "$REPO" "$BLOC" "$EVENT" "$STATE" "$SCREEN" \
  "$ROUTES" "$ROUTE_NAMES" "$ROUTER" "$LOGIN_FORM" "$DI"

ok "FIX 2.3 complete"