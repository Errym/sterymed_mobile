part of '../settings_screen.dart';

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
