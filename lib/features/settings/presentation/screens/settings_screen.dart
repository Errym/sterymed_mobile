import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/config/build_info.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/config/env.dart';
import '../../../../core/push/push_service.dart';
import '../../../../core/router/guards/role_guard.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../../core/sync/sync_status_cubit.dart';
import '../../../../core/utils/role_labels.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../di/di.dart';
import '../../../identity/data/models/tenant_role.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';

part 'settings_screen_parts/profile_header.dart';
part 'settings_screen_parts/hub_row.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionStore>();
    final name = session.userName ?? 'Utilisateur';
    final email = session.userEmail ?? '';
    final role = session.role ?? 'staff';
    final tenant = session.tenantName ?? '';
    final isOwner = session.isOwner;

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Paramètres', showBack: false),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AnimatedListItem(
            index: 0,
            child: _ProfileHeader(
              name: name,
              email: email,
              role: role,
              tenant: tenant,
              isOwner: isOwner,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedListItem(
            index: 1,
            child: _Hub(hasPermission: session.hasPermission),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AnimatedListItem(index: 2, child: _SyncSection()),
          const SizedBox(height: AppSpacing.lg),
          AnimatedListItem(
            index: 3,
            child: _Section(
              title: 'Sécurité',
              children: [
                _InfoTile(
                  icon: Icons.lock_clock_outlined,
                  label: 'Verrouillage automatique',
                  value: 'après ${AppConfig.lockAfter.inMinutes} min',
                ),
                const SizedBox(height: AppSpacing.xs),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'En revenant dans l\'application après ce délai, votre '
                    'code ou votre empreinte est demandé. Les données du '
                    'cabinet sont chiffrées sur le téléphone.',
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedListItem(
            index: 4,
            child: _Section(
              title: 'Session',
              children: [
                SecondaryButton(
                  label: 'Se déconnecter',
                  icon: Icons.logout,
                  onPressed: () async {
                    final ok = await ConfirmationDialog.show(
                      context,
                      title: 'Se déconnecter ?',
                      message:
                          'Vous serez redirigé vers l\'écran de connexion.',
                      confirmLabel: 'Se déconnecter',
                      isDestructive: true,
                    );
                    if (!ok || !context.mounted) return;
                    context.read<AuthBloc>().add(const AuthLogoutRequested());
                    if (context.mounted) {
                      context.go(Routes.login);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(
                  label: 'Se déconnecter partout',
                  icon: Icons.logout_outlined,
                  onPressed: () async {
                    final ok = await ConfirmationDialog.show(
                      context,
                      title: 'Se déconnecter partout ?',
                      message:
                          'Une demande de révocation sera envoyée. La déconnexion locale est immédiate.',
                      confirmLabel: 'Confirmer',
                      isDestructive: true,
                    );
                    if (!ok || !context.mounted) return;
                    context.read<AuthBloc>().add(
                      const AuthLogoutEverywhereRequested(),
                    );
                    if (context.mounted) {
                      context.go(Routes.login);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedListItem(
            index: 5,
            child: _Section(
              title: 'Application',
              children: [
                _InfoTile(
                  icon: Icons.info_outline,
                  label: 'Version',
                  value: BuildInfo.fullVersion,
                ),
                const Divider(
                  height: AppSpacing.lg,
                  color: AppColors.borderLight,
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.cloud_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                      child: Text('Environnement', style: AppTypography.label),
                    ),
                    StatusBadge(
                      label: Env.environment,
                      tone: Env.isProduction
                          ? StatusTone.success
                          : Env.isStaging
                          ? StatusTone.warning
                          : StatusTone.info,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AnimatedListItem(index: 6, child: _PushSection()),
          const SizedBox(height: AppSpacing.lg),
          AnimatedListItem(
            index: 7,
            child: _Section(
              title: 'Support',
              children: [
                _LinkTile(
                  icon: Icons.help_outline,
                  label: 'À propos de SteryMed',
                  onTap: () => context.openRoute(Routes.about),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
