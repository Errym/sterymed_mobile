import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/build_info.dart';
import '../../../../core/config/env.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
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
                      message: 'Toutes les sessions actives seront révoquées.',
                      confirmLabel: 'Confirmer',
                      isDestructive: true,
                    );
                    if (!ok || !context.mounted) return;
                    context
                        .read<AuthBloc>()
                        .add(const AuthLogoutEverywhereRequested());
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
            index: 2,
            child: _Section(
              title: 'Application',
              children: [
                _InfoTile(
                  icon: Icons.info_outline,
                  label: 'Version',
                  value: BuildInfo.fullVersion,
                ),
                const Divider(
                    height: AppSpacing.lg, color: AppColors.borderLight),
                Row(
                  children: [
                    const Icon(Icons.cloud_outlined,
                        size: 18, color: AppColors.textSecondary),
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
          AnimatedListItem(
            index: 3,
            child: _Section(
              title: 'Support',
              children: [
                _LinkTile(
                  icon: Icons.help_outline,
                  label: 'À propos de SteryMed',
                  onTap: () => context.go(Routes.about),
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
        border: Border.all(color: AppColors.borderLight),
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
          Text(name, style: AppTypography.sectionTitle),
          const SizedBox(height: 2),
          Text(email, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusBadge(
                label: isOwner ? 'Administrateur' : 'Personnel',
                tone: isOwner ? StatusTone.info : StatusTone.neutral,
                icon: isOwner ? Icons.shield_outlined : Icons.person_outline,
              ),
              if (tenant.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.xs),
                StatusBadge(label: tenant, icon: Icons.business_outlined),
              ],
            ],
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
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(children: children),
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
          const Icon(Icons.chevron_right,
              size: 18, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
