part of '../dashboard_screen.dart';

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
