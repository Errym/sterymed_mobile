import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/inputs/filter_chip_row.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/list_tile_skeleton.dart';
import '../../../stock/data/models/stock_level_data.dart';
import '../../../stock/data/repositories/stock_repository.dart';
import '../../data/models/product_category_data.dart';
import '../../data/models/product_data.dart';
import '../../data/repositories/product_category_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../bloc/product_list_bloc.dart';
import '../widgets/product_form_sheet.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProductListBloc(getIt<ProductRepository>())
        ..add(const LoadProducts()),
      child: const _ProductListView(),
    );
  }
}

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

class _ProductTile extends StatelessWidget {
  final ProductData product;
  final String? family;
  final int? stock;
  final bool low;
  final VoidCallback onTap;

  const _ProductTile({
    required this.product,
    required this.family,
    required this.stock,
    required this.low,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final eyebrow = [
      if (product.reference.isNotEmpty) product.reference,
      if (product.barcode != null && product.barcode!.isNotEmpty)
        product.barcode!,
    ].join('  ·  ');
    final empty = stock != null && stock == 0;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWell,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(
                  product.isSterilizable
                      ? Icons.sanitizer_outlined
                      : Icons.inventory_2_outlined,
                  size: 21,
                  color: AppColors.navyHeader,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow.isNotEmpty)
                      Text(
                        eyebrow,
                        style: AppTypography.eyebrow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    Text(
                      product.name,
                      style: AppTypography.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (stock != null) ...[
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(
                  label: empty
                      ? 'Rupture'
                      : low
                          ? 'Stock bas'
                          : 'Stock OK',
                  tone: empty || low ? StatusTone.danger : StatusTone.success,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (family != null && family!.isNotEmpty)
                InfoTag(family!, icon: Icons.folder_outlined),
              InfoTag(
                'Unité : ${product.unit}',
                icon: Icons.straighten_outlined,
              ),
              if (product.minThreshold > 0)
                InfoTag(
                  'Seuil ${product.minThreshold} ${product.unit}',
                  icon: Icons.flag_outlined,
                ),
              if (product.isSterilizable)
                const InfoTag(
                  'Stérilisable',
                  icon: Icons.verified_outlined,
                  color: AppColors.success,
                ),
            ],
          ),
          if (stock != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$stock',
                  style: AppTypography.metric.copyWith(
                    fontSize: 22,
                    color: empty || low ? AppColors.danger : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${product.unit} en stock',
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A product in full: identity, thresholds, where it is stored and how much,
/// and (for those who manage the catalogue) edit and delete.
class _ProductSheet extends StatelessWidget {
  final ProductData product;
  final String? family;
  final List<StockLevelData> levels;
  final bool canManage;
  final ProductListBloc bloc;

  /// The catalogue screen's own context: the sheet's context is gone once the
  /// sheet closes, and it has no [ProductListBloc] above it anyway.
  final BuildContext parentContext;

  const _ProductSheet({
    required this.product,
    required this.family,
    required this.levels,
    required this.canManage,
    required this.bloc,
    required this.parentContext,
  });

  static Future<void> show(
    BuildContext context, {
    required ProductData product,
    required String? family,
    required List<StockLevelData> levels,
    required bool canManage,
    required ProductListBloc bloc,
  }) {
    final parentContext = context;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _ProductSheet(
        product: product,
        family: family,
        levels: levels,
        canManage: canManage,
        bloc: bloc,
        parentContext: parentContext,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = levels.fold<int>(0, (s, l) => s + l.qty);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              product.reference.isEmpty
                  ? 'PRODUIT'
                  : 'RÉF. ${product.reference}',
              style: AppTypography.eyebrow,
            ),
            const SizedBox(height: 2),
            Text(product.name, style: AppTypography.sectionTitle),
            const SizedBox(height: AppSpacing.lg),
            FormCard(
              title: 'Fiche produit',
              gap: AppSpacing.xs,
              children: [
                _Row(Icons.tag, 'Référence',
                    product.reference.isEmpty ? '—' : product.reference),
                _Row(Icons.qr_code_2, 'Code-barres',
                    (product.barcode ?? '').isEmpty ? '—' : product.barcode!),
                _Row(Icons.folder_outlined, 'Famille', family ?? '—'),
                _Row(Icons.straighten_outlined, 'Unité', product.unit),
                _Row(
                  Icons.verified_outlined,
                  'Stérilisable',
                  product.isSterilizable ? 'Oui' : 'Non',
                  color: product.isSterilizable ? AppColors.success : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FormCard(
              title: 'Stock',
              gap: AppSpacing.xs,
              children: [
                _Row(Icons.flag_outlined, 'Seuil minimum',
                    '${product.minThreshold} ${product.unit}'),
                _Row(
                  Icons.inventory_2_outlined,
                  'Stock total',
                  '$total ${product.unit}',
                  color: product.minThreshold > 0 && total <= product.minThreshold
                      ? AppColors.danger
                      : null,
                ),
                if (levels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Aucun stock pour ce produit actuellement.',
                      style: AppTypography.caption,
                    ),
                  )
                else
                  for (final l in levels.where((l) => l.qty > 0))
                    _Row(
                      Icons.place_outlined,
                      l.batchNumber == null
                          ? l.locationName
                          : '${l.locationName} · lot ${l.batchNumber}',
                      '${l.qty} ${l.unit}',
                    ),
              ],
            ),
            if (canManage) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (parentContext.mounted) {
                          ProductFormSheet.show(parentContext, existing: product);
                        }
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Modifier'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      onPressed: () async {
                        final ok = await ConfirmationDialog.show(
                          context,
                          title: 'Supprimer le produit ?',
                          message: product.name,
                          confirmLabel: 'Supprimer',
                          isDestructive: true,
                        );
                        if (ok && context.mounted) {
                          Navigator.of(context).pop();
                          bloc.add(DeleteProduct(product.id));
                        }
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Supprimer'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _Row(this.icon, this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.label)),
          Flexible(
            child: Text(
              value,
              style: AppTypography.bodyStrong.copyWith(color: color),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
