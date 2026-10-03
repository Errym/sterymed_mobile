part of '../dashboard_screen.dart';

class _GovernanceMenu extends StatelessWidget {
  const _GovernanceMenu();

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionStore>();
    // Every tile is filtered against the same RoleGuard permission map the
    // router itself enforces (see role_guard.dart) — not `isOwner`, which
    // was hiding tiles a non-owner role's real backend grants already
    // allow (e.g. a practitioner has `sites.view`/`devices.view`) and
    // would have kept showing e.g. "Journal d'Audit" to roles with no
    // `audit.view`, only for the router to bounce them back out. Team has
    // no entry in RoleGuard by design (viewing the list isn't
    // permission-gated server-side, only invite/disable are) so it's
    // always shown, same as the router allows it.
    bool allowed(String route) =>
        RoleGuard.isAllowed(route: route, hasPermission: session.hasPermission);

    final groups = <(String, List<_MenuItem>)>[
      (
        'Opérations',
        [
          const _MenuItem('Cycles de stérilisation',
              'Suivi complet des autoclaves', Icons.autorenew, Routes.cycles),
          const _MenuItem('Stock & Catalogue', 'Niveaux, mouvements et alertes',
              Icons.inventory_2_outlined, Routes.stock),
          const _MenuItem('Lots', 'Lots, DLC et traçabilité',
              Icons.inventory_outlined, Routes.batches),
        ].where((item) => allowed(item.route)).toList(),
      ),
      (
        'Prothèses',
        [
          const _MenuItem(
              'Travaux prothétiques',
              'Suivi empreinte → pose, laboratoires',
              Icons.medical_services_outlined,
              Routes.prosthetic),
        ].where((item) => allowed(item.route)).toList(),
      ),
      (
        'Catalogue & Achats',
        [
          const _MenuItem('Catalogue produits', 'Consommables et références',
              Icons.category_outlined, Routes.products),
          const _MenuItem('Fournisseurs', 'Contacts et références fournisseurs',
              Icons.local_shipping_outlined, Routes.suppliers),
          const _MenuItem(
              'Commandes & Réceptions',
              'Bons de commande et réceptions',
              Icons.shopping_cart_outlined,
              Routes.purchases),
        ].where((item) => allowed(item.route)).toList(),
      ),
      (
        'Clinique & Conformité',
        [
          const _MenuItem(
              'Gestion des patients',
              'Fiches patients et historiques',
              Icons.people_outline,
              Routes.patients),
          const _MenuItem(
              'Non-Conformités & Rappels',
              'Incidents et quarantaines',
              Icons.warning_amber_outlined,
              Routes.nonConformities),
          const _MenuItem('Journal d\'Audit', 'Traces immuables',
              Icons.verified_user_outlined, Routes.audit),
          const _MenuItem(
              'Recherche de preuves',
              'Traçabilité patient, cycle, lot',
              Icons.manage_search_outlined,
              Routes.evidenceSearch),
        ].where((item) => allowed(item.route)).toList(),
      ),
      (
        'Administration',
        [
          const _MenuItem('Équipe & Droits', 'Comptes du personnel',
              Icons.person_add_alt_outlined, Routes.team),
          const _MenuItem('Sites & Espaces', 'Fauteuils et zones stériles',
              Icons.meeting_room_outlined, Routes.sites),
          const _MenuItem('Appareils & Programmes', 'Autoclaves et presets',
              Icons.precision_manufacturing_outlined, Routes.devices),
          const _MenuItem('Règles DLU', 'Durées limite d\'utilisation',
              Icons.timer_outlined, Routes.dluRules),
          const _MenuItem('Export Données', 'Portabilité RGPD / ARS',
              Icons.download_outlined, Routes.dataExports),
        ].where((item) => allowed(item.route)).toList(),
      ),
    ];

    if (groups.every((group) => group.$2.isEmpty)) {
      return const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 40, color: AppColors.textTertiary),
                SizedBox(height: AppSpacing.sm),
                Text('Aucun module accessible', style: AppTypography.sectionTitle),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Contactez votre administrateur pour obtenir des accès.',
                  style: AppTypography.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (title, items) in groups)
          if (items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                  top: AppSpacing.sm, bottom: AppSpacing.xs),
              child: Text(
                title.toUpperCase(),
                style: AppTypography.label.copyWith(
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            for (final item in items) ...[
              _ActionRow(item: item),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
      ],
    );
  }
}

class _ActionRow extends StatefulWidget {
  final _MenuItem item;
  const _ActionRow({required this.item});

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _pressed = false;

  /// Each family of modules has its own tint, so the list reads at a glance.
  (Color, Color) get _tint => switch (widget.item.route) {
        Routes.cycles ||
        Routes.stock ||
        Routes.batches =>
          (AppColors.brandPrimaryLight, AppColors.brandPrimaryDark),
        Routes.prosthetic => (AppColors.warningLight, AppColors.warning),
        Routes.products ||
        Routes.suppliers ||
        Routes.purchases =>
          (AppColors.successLight, AppColors.success),
        Routes.patients ||
        Routes.nonConformities ||
        Routes.audit ||
        Routes.evidenceSearch =>
          (AppColors.infoLight, AppColors.info),
        _ => (AppColors.surfaceWell, AppColors.textPrimary),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _tint;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.openRoute(widget.item.route),
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.hairline),
                boxShadow: AppShadows.card,
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Icon(widget.item.icon, size: 26, color: fg),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          style: AppTypography.cardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.item.subtitle,
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 22,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  const _MenuItem(this.title, this.subtitle, this.icon, this.route);
}


// ─────────────────────────────────────────────────────────────────────────
// Scan hero
// ─────────────────────────────────────────────────────────────────────────
