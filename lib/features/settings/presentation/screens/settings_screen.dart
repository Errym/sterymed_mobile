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

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Paramètres', showBack: false),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const _SectionHeader('Mon compte'),
          _InfoTile(icon: Icons.person_outline, label: 'Nom', value: name),
          _InfoTile(icon: Icons.email_outlined, label: 'E-mail', value: email),
          _InfoTile(icon: Icons.badge_outlined, label: 'Rôle', value: role),
          _InfoTile(
            icon: Icons.business_outlined,
            label: 'Cabinet',
            value: tenant,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader('Session'),
          SecondaryButton(
            label: 'Se déconnecter',
            icon: Icons.logout,
            onPressed: () async {
              final ok = await ConfirmationDialog.show(
                context,
                title: 'Se déconnecter ?',
                message: 'Vous serez redirigé vers l\'écran de connexion.',
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
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader('Application'),
          _InfoTile(
            icon: Icons.info_outline,
            label: 'Version',
            value: BuildInfo.fullVersion,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
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
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader('Support'),
          // ignore: prefer_const_constructors
          _LinkTile(
            icon: Icons.help_outline,
            label: 'À propos de SteryMed',
            onTap: () => context.go(Routes.about),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.label.copyWith(
          letterSpacing: 0.6,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.label)),
          Text(value, style: AppTypography.bodyStrong),
        ],
      ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.brandPrimary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(label, style: AppTypography.bodyStrong)),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
