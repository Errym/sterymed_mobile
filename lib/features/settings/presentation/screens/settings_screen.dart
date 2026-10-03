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

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final String tenant;
  final bool isOwner;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.role,
    required this.tenant,
    required this.isOwner,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.brandPrimaryLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _initials,
                style: AppTypography.pageTitle.copyWith(
                  color: AppColors.brandPrimary,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            name,
            style: AppTypography.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            email,
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              StatusBadge(
                label: tenantRoleLabel(role),
                tone: isOwner ? StatusTone.info : StatusTone.neutral,
                icon: isOwner ? Icons.shield_outlined : Icons.person_outline,
              ),
              if (tenant.isNotEmpty)
                StatusBadge(label: tenant, icon: Icons.business_outlined),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            key: const Key('role-description'),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceWell,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  RoleLabels.focusOf(role).toUpperCase(),
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 2),
                Text(RoleLabels.describe(role), style: AppTypography.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.label.copyWith(
              letterSpacing: 0.6,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.hairline),
            boxShadow: AppShadows.card,
          ),
          // Transparent Material so tiles inside (switches, links) can paint
          // their ink on top of the card instead of being hidden by it.
          child: Material(
            type: MaterialType.transparency,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: AppTypography.label)),
        Text(value, style: AppTypography.bodyStrong),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.brandPrimary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.bodyStrong)),
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

/// The cabinet's administration and compliance screens, in one place. A row
/// is shown only when the role could open that screen (same rule as the
/// router), so nobody is offered a door that answers "forbidden".
class _Hub extends StatelessWidget {
  final bool Function(String permission) hasPermission;
  const _Hub({required this.hasPermission});

  static const _groups = <(String, List<(String, String, IconData, String)>)>[
    (
      'Mon cabinet',
      [
        (
          'Sites et salles',
          'Locaux, zones de stockage',
          Icons.meeting_room_outlined,
          Routes.sites,
        ),
        (
          'Appareils',
          'Autoclaves, programmes, maintenance',
          Icons.precision_manufacturing_outlined,
          Routes.devices,
        ),
        (
          'Équipe',
          'Membres, rôles, invitations',
          Icons.groups_outlined,
          Routes.team,
        ),
        (
          'Règles de DLU',
          'Durées de validité des sachets',
          Icons.timer_outlined,
          Routes.dluRules,
        ),
        (
          'Laboratoires',
          'Partenaires prothèses',
          Icons.science_outlined,
          Routes.prostheticLaboratories,
        ),
      ],
    ),
    (
      'Conformité',
      [
        (
          'Non-conformités',
          'Écarts à traiter',
          Icons.report_problem_outlined,
          Routes.nonConformities,
        ),
        (
          'Journal d\'audit',
          'Qui a fait quoi, et quand',
          Icons.verified_user_outlined,
          Routes.audit,
        ),
        (
          'Recherche de preuves',
          'De la pochette au patient',
          Icons.fact_check_outlined,
          Routes.evidenceSearch,
        ),
        (
          'Exports de données',
          'Archives pour un contrôle',
          Icons.download_outlined,
          Routes.dataExports,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];
    for (final (title, rows) in _groups) {
      final visible = [
        for (final r in rows)
          if (RoleGuard.isAllowed(route: r.$4, hasPermission: hasPermission)) r,
      ];
      if (visible.isEmpty) continue;
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: AppSpacing.lg));
      }
      sections.add(
        _Section(
          title: title,
          children: [
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: AppSpacing.lg,
                  color: AppColors.borderLight,
                ),
              _HubRow(
                icon: visible[i].$3,
                title: visible[i].$1,
                subtitle: visible[i].$2,
                route: visible[i].$4,
              ),
            ],
          ],
        ),
      );
    }
    if (sections.isEmpty) return const SizedBox.shrink();
    return Column(key: const Key('settings-hub'), children: sections);
  }
}

class _HubRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  const _HubRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('hub-$route'),
      onTap: () => context.openRoute(route),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Row(
        children: [
          EntityMark.icon(icon),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyStrong),
                Text(subtitle, style: AppTypography.caption),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

/// Is the phone's work safely on the server? Online or not, how many entries
/// still wait to be sent, and whether any needs a person's attention.
class _SyncSection extends StatelessWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<SyncStatusCubit>()) return const SizedBox.shrink();
    return BlocBuilder<SyncStatusCubit, SyncStatus>(
      bloc: getIt<SyncStatusCubit>(),
      builder: (context, s) {
        final needsYou = s.manualReviewCount + s.quarantinedCount;
        final (label, tone, icon) = !s.online
            ? ('Hors ligne', StatusTone.warning, Icons.cloud_off_outlined)
            : needsYou > 0
            ? ('À vérifier', StatusTone.danger, Icons.error_outline)
            : s.pendingCount > 0
            ? ('En cours d\'envoi', StatusTone.info, Icons.sync)
            : ('À jour', StatusTone.success, Icons.cloud_done_outlined);
        return _Section(
          title: 'Synchronisation',
          children: [
            InkWell(
              key: const Key('settings-sync'),
              onTap: () => context.openRoute(Routes.sync),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Row(
                children: [
                  EntityMark.icon(icon),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Données du cabinet',
                          style: AppTypography.bodyStrong,
                        ),
                        Text(
                          s.pendingCount == 0 && needsYou == 0
                              ? 'Rien en attente d\'envoi.'
                              : [
                                  if (s.pendingCount > 0)
                                    '${s.pendingCount} en attente',
                                  if (needsYou > 0) '$needsYou à vérifier',
                                ].join(' · '),
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(label: label, tone: tone),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}


/// Alert notifications on this phone. Every state says what is true: the
/// build may not carry Firebase settings, the phone may refuse them, or the
/// person may simply have them off.
class _PushSection extends StatelessWidget {
  const _PushSection();

  static const _note = 'Les alertes (stock bas, péremption, cycle en échec) '
      'restent toujours visibles dans l\'onglet Alertes.';

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<PushService>()) {
      return const _Section(
        title: 'Notifications',
        children: [_PushNote(_note, key: Key('alerts-in-app-only'))],
      );
    }
    final service = getIt<PushService>();
    return BlocBuilder<PushService, PushState>(
      bloc: service,
      builder: (context, s) {
        return _Section(
          title: 'Notifications',
          children: switch (s.availability) {
            PushAvailability.notConfigured => const [
                _PushNote(
                  'Les notifications ne sont pas activées dans cette version '
                  'de l\'application. $_note',
                  key: Key('alerts-in-app-only'),
                ),
              ],
            PushAvailability.blocked => [
                const _PushNote(
                  'Ce téléphone refuse les notifications de SteryMed. '
                  'Autorisez-les dans les réglages du téléphone pour être '
                  'prévenu d\'une alerte.',
                  key: Key('push-blocked'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('push-open-settings'),
                    onPressed: openAppSettings,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Ouvrir les réglages'),
                  ),
                ),
              ],
            PushAvailability.off || PushAvailability.on => [
                SwitchListTile(
                  key: const Key('push-switch'),
                  contentPadding: EdgeInsets.zero,
                  value: s.availability == PushAvailability.on,
                  onChanged: s.busy
                      ? null
                      : (on) => on ? service.enable() : service.disable(),
                  title: const Text(
                    'Alertes sur ce téléphone',
                    style: AppTypography.bodyStrong,
                  ),
                  subtitle: const Text(
                    'Un message vous prévient quand une alerte apparaît. Il '
                    'ne contient aucune donnée patient ni nom de produit.',
                    style: AppTypography.caption,
                  ),
                ),
                if (s.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      s.error!,
                      key: const Key('push-error'),
                      style: AppTypography.caption
                          .copyWith(color: AppColors.danger),
                    ),
                  ),
              ],
          },
        );
      },
    );
  }
}

class _PushNote extends StatelessWidget {
  final String text;
  const _PushNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.notifications_none,
          size: 18,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: AppTypography.caption)),
      ],
    );
  }
}
