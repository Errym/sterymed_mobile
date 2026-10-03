part of '../stock_level_list_screen.dart';

class _StockLevelView extends StatelessWidget {
  const _StockLevelView();

  @override
  Widget build(BuildContext context) {
    final canManage = getIt<SessionStore>().hasPermission('inventory.manage');
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Alertes',
            onPressed: () => context.openRoute(Routes.alerts),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => context
                .read<StockLevelListBloc>()
                .add(const RefreshStockLevels()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<StockLevelListBloc, StockLevelListState>(
              builder: (context, state) {
                if (state.status == StockLevelStatus.loading &&
                    state.levels.isEmpty) {
                  return const LoadingView(message: 'Chargement du stock...');
                }
                if (state.status == StockLevelStatus.failure &&
                    state.levels.isEmpty) {
                  return ErrorView(
                    message: state.error ?? 'Erreur',
                    onRetry: () => context
                        .read<StockLevelListBloc>()
                        .add(const LoadStockLevels()),
                  );
                }
                return _StockBody(state: state);
              },
            ),
          ),
          if (canManage)
            PinnedFooter(
              child: PrimaryButton(
                key: const Key('stock-new-movement'),
                label: 'Nouveau mouvement de stock',
                icon: Icons.add,
                onPressed: () => _MovementSheet.show(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _StockBody extends StatelessWidget {
  final StockLevelListState state;
  const _StockBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<StockLevelListBloc>();
    final rows = state.filtered;
    final noStockAtAll = state.levels.isEmpty;
    return RefreshIndicator(
      onRefresh: () async => bloc.add(const RefreshStockLevels()),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PendingChangesBanner(
                    resourceKey: 'stock:',
                    matchPrefix: true,
                  ),
                  _StockSearchBar(
                    query: state.query,
                    onChanged: (q) => bloc.add(SearchStockLevels(q)),
                    onScan: () =>
                        context.openRoute('${Routes.scanner}?mode=product'),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FilterChipRow<StockFilter>(
              selected: state.filter,
              onSelected: (f) =>
                  bloc.add(FilterStockLevels(f ?? StockFilter.all)),
              options: [
                FilterChipOption(
                  value: StockFilter.all,
                  icon: Icons.inventory_2_outlined,
                  label: 'Tous (${state.countFor(StockFilter.all)})',
                ),
                FilterChipOption(
                  value: StockFilter.low,
                  dotColor: AppColors.danger,
                  label: 'Stock bas (${state.countFor(StockFilter.low)})',
                ),
                FilterChipOption(
                  value: StockFilter.perishable,
                  icon: Icons.hourglass_top_outlined,
                  label:
                      'Périssables (${state.countFor(StockFilter.perishable)})',
                ),
                FilterChipOption(
                  value: StockFilter.expired,
                  dotColor: AppColors.textPrimary,
                  label: 'Périmés (${state.countFor(StockFilter.expired)})',
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedListItem(
                    index: 0,
                    child: Row(
                      children: [
                        Expanded(
                          child: _StockMetric(
                            label: 'État global',
                            value: state.healthPercent == null
                                ? '—'
                                : '${state.healthPercent} %',
                            color: _healthColor(state.healthPercent),
                            icon: Icons.verified_outlined,
                            onTap: () => bloc.add(
                              const FilterStockLevels(StockFilter.all),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _StockMetric(
                            label: 'Réappro urgent',
                            value: '${state.urgentReorderCount} réf.',
                            color: state.urgentReorderCount > 0
                                ? AppColors.danger
                                : AppColors.success,
                            icon: Icons.priority_high,
                            onTap: () => bloc.add(
                              const FilterStockLevels(StockFilter.low),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ARTICLES EN CLINIQUE',
                          style: AppTypography.eyebrow,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.swap_vert,
                            size: 14,
                            color: AppColors.brandPrimary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Tri : criticité',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
          if (rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: noStockAtAll
                  ? const EmptyView(
                      title: 'Aucun stock',
                      message:
                          'Réceptionnez une commande pour faire apparaître '
                          'vos produits ici.',
                      icon: Icons.inventory_2_outlined,
                    )
                  : EmptyView(
                      title: 'Aucun résultat',
                      message: 'Modifiez la recherche ou le filtre pour voir '
                          'd\'autres articles.',
                      icon: Icons.search_off_outlined,
                      action: OutlinedButton(
                        onPressed: () {
                          bloc.add(const FilterStockLevels(StockFilter.all));
                          bloc.add(const SearchStockLevels(''));
                        },
                        child: const Text('Réinitialiser le filtre'),
                      ),
                    ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverList.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => AnimatedListItem(
                  index: i,
                  child: StockLevelTile(
                    level: rows[i],
                    onTap: () => _StockDetailSheet.show(context, rows[i]),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }

  static Color _healthColor(int? pct) => pct == null
      ? AppColors.textTertiary
      : pct >= 90
          ? AppColors.success
          : pct >= 70
              ? AppColors.warning
              : AppColors.danger;
}

/// White search bar with a barcode shortcut on the right: scanning a product
/// code opens the product lookup instead of typing a reference. It empties
/// itself when the list's query is reset from elsewhere ("Réinitialiser").
class _StockSearchBar extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onScan;
  const _StockSearchBar({
    required this.query,
    required this.onChanged,
    required this.onScan,
  });

  @override
  State<_StockSearchBar> createState() => _StockSearchBarState();
}
