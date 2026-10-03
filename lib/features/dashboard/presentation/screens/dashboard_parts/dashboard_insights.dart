part of '../dashboard_screen.dart';

/// The one action a clinic repeats all day, put where the thumb is.
class _ScanHero extends StatelessWidget {
  const _ScanHero();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('dashboard-scan-hero'),
        onTap: () => context.openRoute(Routes.scanner),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.navyHeader,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.elevated,
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -34,
                  bottom: -46,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.brandPrimary.withValues(alpha: 0.30),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimaryLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.photo_camera_outlined,
                        color: AppColors.brandPrimaryDark,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scanner une étiquette',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Traçabilité et ouverture de sachet stérile',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              color: AppColors.navyHeaderSubtext,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AllClearTile extends StatelessWidget {
  const _AllClearTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('dashboard-all-clear'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.success),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Rien à traiter pour le moment : stock, commandes et dossiers '
              'sont à jour.',
              style: AppTypography.bodyStrong,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Insight sections (role-dependent)
// ─────────────────────────────────────────────────────────────────────────

class _Metric {
  final String label;
  final String value;
  final Color? color;
  final String? route;
  const _Metric(this.label, this.value, {this.color, this.route});
}

/// A card with a title, an optional lead (health bar) and a grid of figures.
/// Each figure opens the screen it counts, so no number is a dead end.
class _InsightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String route;
  final List<_Metric> metrics;
  final Widget? lead;
  final bool unavailable;
  final String unavailableMessage;

  const _InsightCard({
    required this.title,
    required this.icon,
    required this.route,
    required this.metrics,
    this.lead,
    this.unavailable = false,
    this.unavailableMessage = '',
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.brandPrimary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(title, style: AppTypography.sectionTitle)),
              TextButton(
                onPressed: () => context.openRoute(route),
                child: const Text('Voir tout'),
              ),
            ],
          ),
          if (unavailable)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: _UnavailableTile(message: unavailableMessage),
            )
          else ...[
            if (lead != null) ...[
              const SizedBox(height: AppSpacing.xs),
              lead!,
              const SizedBox(height: AppSpacing.md),
            ],
            LayoutBuilder(
              builder: (context, c) {
                const gap = AppSpacing.sm;
                final w = (c.maxWidth - gap * 2) / 3;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final m in metrics)
                      SizedBox(
                        width: w,
                        child: _MetricTile(
                          metric: m,
                          onTap: () => context.openRoute(m.route ?? route),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final _Metric metric;
  final VoidCallback onTap;
  const _MetricTile({required this.metric, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceWell,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.value,
                style: AppTypography.metric.copyWith(
                  color: metric.color ?? AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                metric.label,
                style: AppTypography.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color? _warnIf(int n, Color color) => n > 0 ? color : null;

class _StockSection extends StatelessWidget {
  final StockInsight? stock;
  final bool unavailable;
  const _StockSection({required this.stock, required this.unavailable});

  @override
  Widget build(BuildContext context) {
    final s = stock;
    final pct = s?.healthPercent;
    final color = pct == null
        ? AppColors.textTertiary
        : pct >= 90
            ? AppColors.success
            : pct >= 70
                ? AppColors.warning
                : AppColors.danger;
    return _InsightCard(
      title: 'Stock',
      icon: Icons.inventory_2_outlined,
      route: Routes.stock,
      unavailable: unavailable || s == null,
      unavailableMessage: 'Stock indisponible : impossible de vérifier.',
      lead: s == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      pct == null ? '—' : '$pct %',
                      style: AppTypography.kpiNumber.copyWith(color: AppColors.text(color)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        s.partial
                            ? 'état global · sur les ${s.rows} premières lignes'
                            : 'état global',
                        key: const Key('stock-health-caption'),
                        style: AppTypography.caption,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: pct == null ? 0 : pct / 100,
                    minHeight: 6,
                    backgroundColor: AppColors.backgroundMuted,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
      metrics: s == null
          ? const []
          : [
              // "12+" when more rows exist than were read: never an exact
              // figure for a partial count.
              _Metric('Sous le minimum', '${s.low}${s.partial ? '+' : ''}',
                  color: _warnIf(s.low, AppColors.warning)),
              _Metric('DLC proche', '${s.nearExpiry}${s.partial ? '+' : ''}',
                  color: _warnIf(s.nearExpiry, AppColors.warning)),
              _Metric('Périmés', '${s.expired}${s.partial ? '+' : ''}',
                  color: _warnIf(s.expired, AppColors.danger)),
            ],
    );
  }
}

class _ProstheticSection extends StatelessWidget {
  final ProstheticInsight? data;
  final bool unavailable;
  const _ProstheticSection({required this.data, required this.unavailable});

  @override
  Widget build(BuildContext context) {
    final d = data;
    return _InsightCard(
      title: 'Prothèses',
      icon: Icons.medical_services_outlined,
      route: Routes.prosthetic,
      unavailable: unavailable || d == null,
      unavailableMessage: 'Prothèses indisponibles : impossible de vérifier.',
      metrics: d == null
          ? const []
          : [
              _Metric('En cours', '${d.active}'),
              _Metric('Au laboratoire', '${d.atLaboratory}'),
              _Metric('Reçues au cabinet', '${d.returned}'),
              _Metric('En attente de pose', '${d.waitingForPlacement}',
                  color: _warnIf(d.waitingForPlacement, AppColors.warning),
                  route: Routes.prostheticWaitingPlacement),
              _Metric('Poses aujourd\'hui', '${d.placementsToday}'),
              _Metric('Soldes à régler', '${d.paymentsDue}',
                  color: _warnIf(d.paymentsDue, AppColors.danger)),
            ],
    );
  }
}

class _PurchaseSection extends StatelessWidget {
  final PurchaseInsight? data;
  final bool unavailable;
  const _PurchaseSection({required this.data, required this.unavailable});

  @override
  Widget build(BuildContext context) {
    final d = data;
    return _InsightCard(
      title: 'Commandes',
      icon: Icons.shopping_cart_outlined,
      route: Routes.purchases,
      unavailable: unavailable || d == null,
      unavailableMessage: 'Commandes indisponibles : impossible de vérifier.',
      metrics: d == null
          ? const []
          : [
              _Metric('À réceptionner', '${d.toReceive}'),
              _Metric('En retard', '${d.late}',
                  color: _warnIf(d.late, AppColors.danger)),
            ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Recent activity
// ─────────────────────────────────────────────────────────────────────────
