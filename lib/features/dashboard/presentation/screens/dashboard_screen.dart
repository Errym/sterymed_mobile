import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/router/guards/role_guard.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/role_labels.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../shell/presentation/widgets/profile_menu.dart';
import '../../data/models/dashboard_data.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DashboardCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionStore>();
    final name = session.userName ?? 'Utilisateur';
    final email = session.userEmail ?? '';
    final role = session.role ?? 'Aucun rôle';
    final isOwner = session.isOwner;

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(name: name, email: email, role: role),
            Expanded(
              child: BlocBuilder<DashboardCubit, DashboardState>(
                builder: (context, state) {
                  if (state is DashboardError) {
                    return ErrorView(
                      message: state.message,
                      onRetry: () => context.read<DashboardCubit>().load(),
                    );
                  }

                  final data = state is DashboardLoaded ? state.data : null;

                  return RefreshIndicator(
                    onRefresh: () => context.read<DashboardCubit>().load(),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: data == null
                          ? const _DashboardSkeleton(key: ValueKey('skeleton'))
                          : _DashboardContent(
                              key: const ValueKey('content'),
                              data: data,
                              name: name,
                              email: email,
                              role: role,
                              isOwner: isOwner,
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bar that stays on screen: the product mark and the clinic on the left,
/// the alert bell (with a dot when something is open) and the account on the
/// right.
class _TopBar extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  const _TopBar({required this.name, required this.email, required this.role});

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionStore>();
    final clinic = session.tenantName;
    final canAlerts = session.hasPermission('alerts.view');
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.backgroundApp,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.navyHeader,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.card,
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SteryMed',
                  style: AppTypography.cardTitle.copyWith(
                    color: AppColors.navyHeader,
                    height: 1.1,
                  ),
                ),
                if (clinic != null && clinic.isNotEmpty)
                  Text(
                    clinic.toUpperCase(),
                    style: AppTypography.eyebrow.copyWith(
                      fontSize: 10,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (canAlerts)
            BlocBuilder<DashboardCubit, DashboardState>(
              builder: (context, state) {
                final open = state is DashboardLoaded
                    ? state.data.kpis
                        .where((k) => k.id == 'pending_alerts')
                        .map((k) => k.value ?? 0)
                        .fold<int>(0, (a, b) => a + b)
                    : 0;
                return _BellButton(
                  hasOpen: open > 0,
                  onTap: () => context.openRoute(Routes.alerts),
                );
              },
            ),
          ProfileMenu(displayName: name, email: email, role: role),
        ],
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  final bool hasOpen;
  final VoidCallback onTap;
  const _BellButton({required this.hasOpen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: hasOpen ? 'Alertes : certaines sont ouvertes' : 'Alertes',
      child: InkWell(
        key: const Key('dashboard-bell'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.backgroundCard,
            shape: BoxShape.circle,
            boxShadow: AppShadows.card,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.notifications_outlined, size: 20),
              if (hasOpen)
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.backgroundCard,
                        width: 1.5,
                      ),
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

class _DashboardContent extends StatelessWidget {
  final DashboardData data;
  final String name;
  final String email;
  final String role;
  final bool isOwner;

  const _DashboardContent({
    super.key,
    required this.data,
    required this.name,
    required this.email,
    required this.role,
    required this.isOwner,
  });

  /// What needs a person today, built only from figures the server returned
  /// and only for what this role may act on. Worst first.
  List<DashboardAttentionItem> _todos(SessionStore s) {
    final ins = data.insights;
    final out = <DashboardAttentionItem>[];
    void add(String id, String label, String severity, String route) =>
        out.add(DashboardAttentionItem(
          id: id,
          label: label,
          severity: severity,
          route: route,
        ));
    String plural(int n, String one, String many) => n > 1 ? many : one;

    final stock = ins.stock;
    if (stock != null && stock.expired > 0) {
      add('expired', '${stock.expired} ${plural(stock.expired, 'lot périmé à retirer', 'lots périmés à retirer')} du stock',
          'critical', Routes.stock);
    }
    final rel = ins.awaitingRelease;
    if (rel != null && rel > 0 && s.hasPermission('cycles.release')) {
      add('release', '$rel ${plural(rel, 'cycle attend', 'cycles attendent')} votre décision de libération',
          'warning', Routes.cycles);
    }
    final po = ins.purchases;
    if (po != null && po.late > 0) {
      add('late', '${po.late} ${plural(po.late, 'commande en retard', 'commandes en retard')} de livraison',
          'critical', Routes.purchases);
    }
    if (stock != null && stock.low > 0) {
      add('low', '${stock.low} ${plural(stock.low, 'ligne de stock sous', 'lignes de stock sous')} le minimum',
          'warning', Routes.stock);
    }
    if (stock != null && stock.nearExpiry > 0) {
      add('near', '${stock.nearExpiry} ${plural(stock.nearExpiry, 'lot proche', 'lots proches')} de la date limite',
          'warning', Routes.stock);
    }
    if (po != null && po.toReceive > 0) {
      add('receive', '${po.toReceive} ${plural(po.toReceive, 'commande à réceptionner', 'commandes à réceptionner')}',
          'info', Routes.purchases);
    }
    final pro = ins.prosthetic;
    if (pro != null && pro.waitingForPlacement > 0) {
      add('placement', '${pro.waitingForPlacement} ${plural(pro.waitingForPlacement, 'prothèse en attente', 'prothèses en attente')} de pose',
          'warning', Routes.prostheticWaitingPlacement);
    }
    if (pro != null && pro.placementsToday > 0) {
      add('today', '${pro.placementsToday} ${plural(pro.placementsToday, 'pose prévue', 'poses prévues')} aujourd\'hui',
          'info', Routes.prosthetic);
    }
    if (pro != null && pro.paymentsDue > 0) {
      add('payments', '${pro.paymentsDue} ${plural(pro.paymentsDue, 'dossier avec un solde', 'dossiers avec un solde')} à régler',
          'info', Routes.prosthetic);
    }
    return out;
  }


  /// The three figures this role cares about most, each one a door to the
  /// screen it counts. Built from what the server returned for this role:
  /// a figure the role may not see is never shown, one that could not be read
  /// is a dash.
  List<_KpiSpec> _kpiSpecs() {
    final ins = data.insights;
    DashboardKpi? kpi(String id) {
      for (final k in data.kpis) {
        if (k.id == id) return k;
      }
      return null;
    }

    _KpiSpec? fromKpi(String id, String label, IconData icon, Color accent,
        {bool attention = false}) {
      final k = kpi(id);
      if (k == null) return null;
      return _KpiSpec(
        label: label,
        value: k.value,
        approximate: k.approximate,
        icon: icon,
        accent: accent,
        route: k.route,
        attention: attention,
      );
    }

    _KpiSpec? fromInsight(
      String section,
      Object? present,
      String label,
      int Function() value,
      IconData icon,
      Color accent,
      String route, {
      bool attention = false,
    }) {
      if (present == null && !ins.unavailable.contains(section)) return null;
      return _KpiSpec(
        label: label,
        value: present == null ? null : value(),
        icon: icon,
        accent: accent,
        route: route,
        attention: attention,
      );
    }

    final byKey = <String, _KpiSpec? Function()>{
      'cycles': () => fromKpi('active_cycles', 'Cycles en cours',
          Icons.autorenew, AppColors.brandPrimary),
      'alerts': () => fromKpi('pending_alerts', 'Alertes actives',
          Icons.notification_important_outlined, AppColors.warning,
          attention: true),
      'today': () => fromKpi('today_cycles', 'Cycles du jour',
          Icons.today_outlined, AppColors.info),
      'audit': () => fromKpi('audit_events', 'Événements récents',
          Icons.fact_check_outlined, AppColors.success),
      'low': () => fromInsight('stock', ins.stock, 'Sous le minimum',
          () => ins.stock!.low, Icons.inventory_2_outlined, AppColors.warning,
          Routes.stock,
          attention: true),
      'receive': () => fromInsight(
          'purchases',
          ins.purchases,
          'À réceptionner',
          () => ins.purchases!.toReceive,
          Icons.local_shipping_outlined,
          AppColors.brandPrimary,
          Routes.purchases),
      'release': () => ins.awaitingRelease == null
          ? null
          : _KpiSpec(
              label: 'À libérer',
              value: ins.awaitingRelease,
              icon: Icons.verified_outlined,
              accent: AppColors.warning,
              route: Routes.cycles,
              attention: true,
            ),
      'p_active': () => fromInsight(
          'prosthetic',
          ins.prosthetic,
          'Prothèses en cours',
          () => ins.prosthetic!.active,
          Icons.medical_services_outlined,
          AppColors.brandPrimary,
          Routes.prosthetic),
      'p_returned': () => fromInsight(
          'prosthetic',
          ins.prosthetic,
          'Reçues au cabinet',
          () => ins.prosthetic!.returned,
          Icons.inventory_2_outlined,
          AppColors.success,
          Routes.prosthetic),
      'p_wait': () => fromInsight(
          'prosthetic',
          ins.prosthetic,
          'En attente de pose',
          () => ins.prosthetic!.waitingForPlacement,
          Icons.event_available_outlined,
          AppColors.warning,
          Routes.prostheticWaitingPlacement,
          attention: true),
    };

    // What each role looks at first; anything missing is filled from the
    // common list so the row is never half empty.
    final order = switch (role) {
      'stock_manager' => ['low', 'receive', 'alerts'],
      'releaser' => ['release', 'cycles', 'alerts'],
      'practitioner' => ['p_active', 'p_returned', 'p_wait'],
      _ => ['cycles', 'alerts', 'p_wait'],
    };
    const fallback = [
      'cycles', 'alerts', 'today', 'low', 'receive', 'p_wait', 'audit',
    ];
    final out = <_KpiSpec>[];
    final used = <String>{};
    for (final key in [...order, ...fallback]) {
      if (out.length == 3) break;
      if (!used.add(key)) continue;
      final spec = byKey[key]!();
      if (spec != null) out.add(spec);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionStore>();
    final ins = data.insights;
    final kpiSpecs = _kpiSpecs();
    final showsCycles = data.kpis.any(
          (k) => k.id == 'active_cycles' || k.id == 'today_cycles',
        ) ||
        data.unavailable.contains('cycles');
    final showsActivity = data.kpis.any((k) => k.id == 'audit_events');
    final todos = _todos(session);
    final attention = [...todos, ...data.attention];
    final nothingToDo = attention.isEmpty &&
        !data.hasUnavailable &&
        (ins.stock != null || ins.purchases != null || ins.prosthetic != null);
    var i = 0;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AnimatedListItem(
          index: i++,
          child: _Header(
            name: name,
            email: email,
            role: role,
            greeting: data.greeting,
            data: data,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (data.hasUnavailable || data.stale) ...[
          _DataStatusBanner(data: data),
          const SizedBox(height: AppSpacing.md),
        ],
        if (session.hasPermission('labels.view')) ...[
          AnimatedListItem(index: i++, child: const _ScanHero()),
          const SizedBox(height: AppSpacing.md),
        ],
        if (kpiSpecs.isNotEmpty) ...[
          AnimatedListItem(index: i++, child: _KpiRow(specs: kpiSpecs)),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (data.unavailable.contains('alerts')) ...[
          const _UnavailableTile(
            key: Key('dashboard-alerts-unavailable'),
            message:
                'Alertes indisponibles : impossible de vérifier. Réessayez.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (attention.isNotEmpty) ...[
          AnimatedListItem(
            index: i++,
            child: const SectionHeader(title: 'Nécessite votre attention'),
          ),
          for (final item in attention)
            AnimatedListItem(
              index: i++,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _AttentionTile(item: item),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ] else if (nothingToDo) ...[
          AnimatedListItem(index: i++, child: const _AllClearTile()),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (ins.stock != null || ins.unavailable.contains('stock')) ...[
          AnimatedListItem(
            index: i++,
            child: _StockSection(
              stock: ins.stock,
              unavailable: ins.unavailable.contains('stock'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (ins.prosthetic != null || ins.unavailable.contains('prosthetic')) ...[
          AnimatedListItem(
            index: i++,
            child: _ProstheticSection(
              data: ins.prosthetic,
              unavailable: ins.unavailable.contains('prosthetic'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (ins.purchases != null || ins.unavailable.contains('purchases')) ...[
          AnimatedListItem(
            index: i++,
            child: _PurchaseSection(
              data: ins.purchases,
              unavailable: ins.unavailable.contains('purchases'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (showsCycles) ...[
          AnimatedListItem(
            index: i++,
            child: _TodayCyclesSection(
              cycles: data.todayCycles,
              unavailable: data.unavailable.contains('cycles'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (showsActivity && data.recentProcedures.isNotEmpty) ...[
          AnimatedListItem(
            index: i++,
            child: _ActivitySection(items: data.recentProcedures),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        AnimatedListItem(
          index: i++,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isOwner ? 'Centre de gouvernance' : 'Modules du cabinet',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: 2),
              Text(
                isOwner
                    ? 'Tous les espaces de travail et réglages du cabinet'
                    : 'Accédez rapidement à vos espaces de travail',
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedListItem(
          index: i++,
          child: const _GovernanceMenu(),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 13, color: AppColors.textTertiary),
            SizedBox(width: 6),
            Text(
              'Session sécurisée · données chiffrées sur cet appareil',
              style: AppTypography.caption,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Skeleton (loading state)
// ─────────────────────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget block({double width = double.infinity, double height = 14}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
      );
    }

    Widget card({required double height}) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: AppColors.backgroundMuted,
      highlightColor: AppColors.backgroundSubtle,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    block(width: 180, height: 22),
                    const SizedBox(height: AppSpacing.xs),
                    block(width: 140, height: 12),
                  ],
                ),
              ),
              const CircleAvatar(radius: 18, backgroundColor: Colors.white),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              mainAxisExtent: 100,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => card(height: 100),
          ),
          const SizedBox(height: AppSpacing.lg),
          block(width: 160, height: 14),
          const SizedBox(height: AppSpacing.sm),
          card(height: 140),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 4; i++) ...[
            card(height: 64),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final String greeting;
  final DashboardData data;

  const _Header({
    required this.name,
    required this.email,
    required this.role,
    required this.greeting,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TABLEAU DE BORD', style: AppTypography.eyebrow),
              const SizedBox(height: 2),
              Text(
                '$greeting, $name',
                style: AppTypography.pageTitle.copyWith(fontSize: 24),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimaryLight,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      RoleLabels.of(role),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    RoleLabels.focusOf(role),
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _FreshnessPill(data: data),
      ],
    );
  }
}

/// Whether what is on screen can be trusted right now: read from the server
/// and complete, partly missing, or an earlier read kept after a failed
/// refresh.
class _FreshnessPill extends StatelessWidget {
  final DashboardData data;
  const _FreshnessPill({required this.data});

  @override
  Widget build(BuildContext context) {
    final (label, color) = data.stale
        ? ('Hors ligne', AppColors.textSecondary)
        : data.hasUnavailable
            ? ('Partiel', AppColors.warning)
            : ('À jour', AppColors.success);
    return Container(
      key: const Key('dashboard-freshness'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// KPI grid
// ─────────────────────────────────────────────────────────────────────────

/// One of the three headline figures. [value] null means "could not be read":
/// shown as a dash, never as a zero.
class _KpiSpec {
  final String label;
  final int? value;
  final bool approximate;
  final IconData icon;
  final Color accent;
  final String route;

  /// Something that wants action: the tile is tinted warm.
  final bool attention;
  const _KpiSpec({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.route,
    this.approximate = false,
    this.attention = false,
  });
}

class _KpiRow extends StatelessWidget {
  final List<_KpiSpec> specs;
  const _KpiRow({required this.specs});

  @override
  Widget build(BuildContext context) {
    if (specs.isEmpty) return const SizedBox.shrink();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < specs.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: _KpiTile(spec: specs[i])),
          ],
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final _KpiSpec spec;
  const _KpiTile({required this.spec});

  @override
  Widget build(BuildContext context) {
    final unavailable = spec.value == null;
    final warm = spec.attention && !unavailable && (spec.value ?? 0) > 0;
    final accent = unavailable ? AppColors.textTertiary : spec.accent;
    final shown = unavailable
        ? '—'
        : spec.approximate
            ? '${spec.value}+'
            : '${spec.value}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.openRoute(spec.route),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: warm ? AppColors.warningLight : AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  unavailable ? Icons.cloud_off_outlined : spec.icon,
                  size: 17,
                  color: accent,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  shown,
                  style: AppTypography.kpiNumber.copyWith(
                    fontSize: 24,
                    color: warm ? AppColors.warning : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                spec.label,
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
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

// ─────────────────────────────────────────────────────────────────────────
// Data honesty: unavailable / stale
// ─────────────────────────────────────────────────────────────────────────

class _DataStatusBanner extends StatelessWidget {
  final DashboardData data;
  const _DataStatusBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    final at = data.fetchedAt;
    final time = at == null
        ? ''
        : ' (données de ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')})';
    final text = data.stale
        ? 'Actualisation impossible : ces chiffres peuvent être périmés$time.'
        : 'Certaines données sont indisponibles. Les tirets ne sont pas des zéros.';
    return Container(
      key: const Key('dashboard-status-banner'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTypography.caption)),
          TextButton(
            onPressed: () => context.read<DashboardCubit>().load(),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _UnavailableTile extends StatelessWidget {
  final String message;
  const _UnavailableTile({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.cloud_off_outlined,
            size: 18, color: AppColors.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Attention tiles
// ─────────────────────────────────────────────────────────────────────────

class _AttentionTile extends StatelessWidget {
  final DashboardAttentionItem item;
  const _AttentionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon) = switch (item.severity) {
      'critical' => (
          AppColors.danger,
          AppColors.dangerLight,
          Icons.error_outline
        ),
      'warning' => (
          AppColors.warning,
          AppColors.warningLight,
          Icons.warning_amber_outlined
        ),
      _ => (AppColors.info, AppColors.infoLight, Icons.info_outline),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.openRoute(item.route),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.hairline),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: fg,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppRadius.md),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration:
                              BoxDecoration(color: bg, shape: BoxShape.circle),
                          child: Icon(icon, color: fg, size: 16),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child:
                              Text(item.label, style: AppTypography.bodyStrong),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppColors.textTertiary, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Today's cycles
// ─────────────────────────────────────────────────────────────────────────

class _TodayCyclesSection extends StatelessWidget {
  final List<DashboardTodayCycle> cycles;
  final bool unavailable;
  const _TodayCyclesSection({required this.cycles, this.unavailable = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child:
                    Text('Cycles du jour', style: AppTypography.sectionTitle),
              ),
              TextButton(
                onPressed: () => context.openRoute(Routes.cycles),
                child: const Text('Voir tout'),
              ),
            ],
          ),
          if (unavailable)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: _UnavailableTile(
                key: Key('dashboard-cycles-unavailable'),
                message: 'Cycles indisponibles. Tirez pour actualiser.',
              ),
            )
          else if (cycles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(Icons.event_available_outlined,
                      color: AppColors.textTertiary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Aucun cycle aujourd\'hui.',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            for (final c in cycles)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: InkWell(
                  onTap: () => context.openRoute(Routes.cyclesDetail(c.id)),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cycle ${c.number}',
                                  style: AppTypography.bodyStrong),
                              const SizedBox(height: 2),
                              Text(c.deviceName, style: AppTypography.caption),
                            ],
                          ),
                        ),
                        _statusBadge(c.status),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case 'released':
        return const TypeBadge(label: 'Libéré', tone: BadgeTone.green);
      case 'in_progress':
        return const TypeBadge(label: 'En cours', tone: BadgeTone.blue);
      case 'awaiting_release':
        return const TypeBadge(
            label: 'Contrôles saisis', tone: BadgeTone.yellow);
      case 'rejected':
        return const TypeBadge(label: 'Rejeté', tone: BadgeTone.red);
      case 'completed':
        return const TypeBadge(label: 'Terminé', tone: BadgeTone.orange);
      default:
        return const TypeBadge(label: 'Créé', tone: BadgeTone.gray);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Quick access / governance menu
// ─────────────────────────────────────────────────────────────────────────

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
                      style: AppTypography.kpiNumber.copyWith(color: color),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text('état global', style: AppTypography.caption),
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
              _Metric('Sous le minimum', '${s.low}',
                  color: _warnIf(s.low, AppColors.warning)),
              _Metric('DLC proche', '${s.nearExpiry}',
                  color: _warnIf(s.nearExpiry, AppColors.warning)),
              _Metric('Périmés', '${s.expired}',
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

class _ActivitySection extends StatelessWidget {
  final List<DashboardRecentProcedure> items;
  const _ActivitySection({required this.items});

  /// "à l'instant", "il y a 12 min", "il y a 3 h", else the date.
  static String _when(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '•';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Activité récente', style: AppTypography.sectionTitle),
            ),
            TextButton.icon(
              onPressed: () => context.openRoute(Routes.audit),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right, size: 16),
              label: const Text('Voir tout'),
            ),
          ],
        ),
        for (final e in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              onTap: () => context.openRoute(Routes.audit),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.brandPrimaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _initials(e.actor),
                      style: AppTypography.bodyStrong.copyWith(
                        color: AppColors.brandPrimaryDark,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.label,
                          style: AppTypography.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (e.actor.isNotEmpty) e.actor,
                            _when(e.usedAt),
                          ].where((s) => s.isNotEmpty).join('  ·  '),
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
