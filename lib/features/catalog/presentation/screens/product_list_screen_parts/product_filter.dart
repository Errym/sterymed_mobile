part of '../product_list_screen.dart';

enum _ProductFilter { all, sterilizable, low }

/// What the catalogue shows next to each product besides the product itself:
/// how much of it is on the shelves, and its family's name. Both are read
/// separately and are optional: if either cannot be read, the list still
/// works and simply omits that detail.
class _CatalogExtras {
  final Map<String, int> stockByProduct;
  final List<StockLevelData> levels;
  final Map<String, String> familyNames;
  const _CatalogExtras({
    this.stockByProduct = const {},
    this.levels = const [],
    this.familyNames = const {},
  });

  bool get hasStock => levels.isNotEmpty || stockByProduct.isNotEmpty;
}

class _ProductListView extends StatefulWidget {
  const _ProductListView();

  @override
  State<_ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends State<_ProductListView> {
  _ProductFilter _filter = _ProductFilter.all;
  _CatalogExtras _extras = const _CatalogExtras();

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    var stock = <String, int>{};
    var levels = <StockLevelData>[];
    var families = <String, String>{};
    try {
      levels = await getIt<StockRepository>().listLevels();
      for (final l in levels) {
        stock[l.productId] = (stock[l.productId] ?? 0) + l.qty;
      }
    } catch (_) {
      stock = {};
      levels = [];
    }
    try {
      final cats = await getIt<ProductCategoryRepository>().list();
      families = {for (final ProductCategoryData c in cats) c.id: c.name};
    } catch (_) {
      families = {};
    }
    if (!mounted) return;
    setState(() => _extras = _CatalogExtras(
          stockByProduct: stock,
          levels: levels,
          familyNames: families,
        ));
  }

  /// Under its minimum: nothing on the shelves, or at or below the threshold.
  bool _isLow(ProductData p) {
    if (!_extras.hasStock) return false;
    final qty = _extras.stockByProduct[p.id] ?? 0;
    return p.minThreshold > 0 && qty <= p.minThreshold;
  }

  List<ProductData> _apply(List<ProductData> all) {
    return all.where((p) {
      switch (_filter) {
        case _ProductFilter.all:
          return true;
        case _ProductFilter.sterilizable:
          return p.isSterilizable;
        case _ProductFilter.low:
          return _isLow(p);
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = getIt<SessionStore>().hasPermission('products.manage');

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Catalogue produits',
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nouveau produit',
              onPressed: () => ProductFormSheet.show(context),
            ),
        ],
      ),
      body: BlocConsumer<ProductListBloc, ProductListState>(
        listenWhen: (a, b) =>
            b.actionError != null && a.actionError != b.actionError,
        listener: (context, state) {
          AppSnackbar.show(
            context,
            state.actionError!,
            kind: SnackKind.error,
          );
          context.read<ProductListBloc>().add(
            const ClearProductActionError(),
          );
        },
        builder: (context, state) {
          final products = state.products;
          final shown = _apply(products);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    boxShadow: AppShadows.card,
                  ),
                  child: TextField(
                    onChanged: (q) =>
                        context.read<ProductListBloc>().add(SearchProducts(q)),
                    style: AppTypography.body,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un produit, une référence...',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              FilterChipRow<_ProductFilter>(
                selected: _filter,
                onSelected: (f) =>
                    setState(() => _filter = f ?? _ProductFilter.all),
                options: [
                  FilterChipOption(
                    value: _ProductFilter.all,
                    icon: Icons.category_outlined,
                    label: 'Tous (${products.length})',
                  ),
                  FilterChipOption(
                    value: _ProductFilter.sterilizable,
                    icon: Icons.sanitizer_outlined,
                    label:
                        'Stérilisables (${products.where((p) => p.isSterilizable).length})',
                  ),
                  if (_extras.hasStock)
                    FilterChipOption(
                      value: _ProductFilter.low,
                      dotColor: AppColors.danger,
                      label: 'Sous le minimum '
                          '(${products.where(_isLow).length})',
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(child: _body(context, state, shown, canManage)),
            ],
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    ProductListState state,
    List<ProductData> shown,
    bool canManage,
  ) {
    if (state.status == ProductListStatus.loading && state.products.isEmpty) {
      return const ListSkeleton();
    }
    if (state.status == ProductListStatus.failure) {
      return ErrorView(
        message: state.error ?? 'Erreur',
        onRetry: () =>
            context.read<ProductListBloc>().add(const LoadProducts()),
      );
    }
    if (state.products.isEmpty) {
      return EmptyView(
        title: 'Aucun produit',
        message: canManage
            ? 'Ajoutez votre premier produit au catalogue.'
            : 'Le catalogue est vide pour le moment.',
        icon: Icons.inventory_2_outlined,
        action: canManage
            ? FilledButton.icon(
                onPressed: () => ProductFormSheet.show(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouveau produit'),
              )
            : null,
      );
    }
    if (shown.isEmpty) {
      return const EmptyView(
        title: 'Aucun produit',
        message: 'Aucun produit ne correspond à ce filtre.',
        icon: Icons.search_off_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        context.read<ProductListBloc>().add(const LoadProducts());
        await _loadExtras();
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        itemCount: shown.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) {
          final p = shown[i];
          return AnimatedListItem(
            index: i,
            child: _ProductTile(
              product: p,
              family: _extras.familyNames[p.categoryId],
              stock: _extras.hasStock ? (_extras.stockByProduct[p.id] ?? 0) : null,
              low: _isLow(p),
              onTap: () => _ProductSheet.show(
                context,
                product: p,
                family: _extras.familyNames[p.categoryId],
                levels: _extras.levels.where((l) => l.productId == p.id).toList(),
                canManage: canManage,
                bloc: context.read<ProductListBloc>(),
              ),
            ),
          );
        },
      ),
    );
  }
}
