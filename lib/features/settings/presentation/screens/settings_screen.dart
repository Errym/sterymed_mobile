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
          const SizedBox(height: AppSpacing.md),
          AnimatedListItem(
            index: 1,
            child: _Hub(hasPermission: session.hasPermission),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedListItem(
            index: 2,
            child: _Section(
              title: 'Application',
              children: [
                const _SyncSection(),
                const _RowDivider(),
                _InfoTile(
                  icon: Icons.lock_clock_outlined,
                  label: 'Verrouillage automatique',
                  value: 'après ${AppConfig.lockAfter.inMinutes} min',
                ),
                const _RowDivider(),
                const _PushSection(),
                const _RowDivider(),
                _InfoTile(
                  icon: Icons.info_outline,
                  label: 'Version',
                  value: BuildInfo.fullVersion,
                ),
                // The environment matters to a tester, not to a clinic: only
                // shown when this is not the production build.
                if (!Env.isProduction) ...[
                  const _RowDivider(),
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
                        tone: Env.isStaging
                            ? StatusTone.warning
                            : StatusTone.info,
                      ),
                    ],
                  ),
                ],
                const _RowDivider(),
                _LinkTile(
                  icon: Icons.help_outline,
                  label: 'À propos de SteryMed',
                  onTap: () => context.openRoute(Routes.about),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedListItem(
            index: 3,
            child: Column(
              children: [
                SecondaryButton(
                  label: 'Se déconnecter',
                  icon: Icons.logout,
                  onPressed: () async {
                    final ok = await ConfirmationDialog.show(
                      context,
                      title: 'Se déconnecter ?',
                      message:
                          "Vous serez redirigé vers l'écran de connexion.",
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
                TextButton(
                  key: const Key('logout-everywhere'),
                  onPressed: () async {
                    final ok = await ConfirmationDialog.show(
                      context,
                      title: 'Se déconnecter partout ?',
                      message:
                          'Tous les appareils connectés à votre compte seront déconnectés. La déconnexion de ce téléphone est immédiate.',
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
                  child: const Text('Se déconnecter partout'),
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
