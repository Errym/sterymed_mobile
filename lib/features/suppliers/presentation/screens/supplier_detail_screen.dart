import 'package:flutter/material.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../catalog/data/models/product_data.dart';
import '../../../catalog/data/repositories/product_repository.dart';
import '../../data/models/supplier_data.dart';
import '../../data/models/supplier_product_data.dart';
import '../../data/repositories/supplier_repository.dart';

class SupplierDetailScreen extends StatefulWidget {
  final String supplierId;
  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  late Future<
          (SupplierData?, List<SupplierProductData>, Map<String, ProductData>)>
      _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(SupplierData?, List<SupplierProductData>, Map<String, ProductData>)>
      _load() async {
    final results = await Future.wait([
      getIt<SupplierRepository>().list(),
      getIt<SupplierRepository>()
          .listProducts(widget.supplierId, forceRefresh: true),
      getIt<ProductRepository>().list(),
    ]);
    final suppliers = results[0] as List<SupplierData>;
    final links = results[1] as List<SupplierProductData>;
    final products = results[2] as List<ProductData>;
    SupplierData? supplier;
    for (final s in suppliers) {
      if (s.id == widget.supplierId) {
        supplier = s;
        break;
      }
    }
    final byId = {for (final p in products) p.id: p};
    return (supplier, links, byId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _addProduct(List<ProductData> allProducts) async {
    final added = await _AttachProductSheet.show(
      context,
      supplierId: widget.supplierId,
      products: allProducts,
    );
    if (added == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = getIt<SessionStore>().hasPermission('suppliers.manage');
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Fournisseur'),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snap.hasError) {
            return ErrorView(
              message: 'Impossible de charger le fournisseur.',
              onRetry: _refresh,
            );
          }
          final (supplier, links, productsById) = snap.data!;
          if (supplier == null) {
            return const ErrorView(message: 'Fournisseur introuvable.');
          }
          final allProducts = productsById.values.toList();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AnimatedListItem(
                  index: 0,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(supplier.name, style: AppTypography.sectionTitle),
                        if (supplier.email != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(supplier.email!, style: AppTypography.caption),
                        ],
                        if (supplier.phone != null) ...[
                          const SizedBox(height: 2),
                          Text(supplier.phone!, style: AppTypography.caption),
                        ],
                        if (supplier.address != null) ...[
                          const SizedBox(height: 2),
                          Text(supplier.address!, style: AppTypography.caption),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Produits fournis (${links.length})',
                        style: AppTypography.sectionTitle),
                    if (canManage)
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Lier un produit',
                        onPressed: () => _addProduct(allProducts),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (links.isEmpty)
                  EmptyView(
                    title: 'Aucun produit lié',
                    message: canManage
                        ? 'Liez les produits que ce fournisseur peut livrer.'
                        : 'Aucun produit n\'est encore lié à ce fournisseur.',
                    icon: Icons.inventory_2_outlined,
                  )
                else
                  for (var i = 0; i < links.length; i++)
                    AnimatedListItem(
                      index: i + 1,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _SupplierProductTile(
                          link: links[i],
                          product: productsById[links[i].productId],
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SupplierProductTile extends StatelessWidget {
  final SupplierProductData link;
  final ProductData? product;
  const _SupplierProductTile({required this.link, required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product?.name ?? 'Produit inconnu',
                    style: AppTypography.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  [
                    if (link.supplierReference != null)
                      'Réf. ${link.supplierReference}',
                    'Conditionnement ×${link.packSize}',
                    if (link.price != null)
                      '${link.price!.toStringAsFixed(2)} €',
                  ].join(' · '),
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachProductSheet extends StatefulWidget {
  final String supplierId;
  final List<ProductData> products;
  const _AttachProductSheet({required this.supplierId, required this.products});

  static Future<bool?> show(
    BuildContext context, {
    required String supplierId,
    required List<ProductData> products,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) =>
          _AttachProductSheet(supplierId: supplierId, products: products),
    );
  }

  @override
  State<_AttachProductSheet> createState() => _AttachProductSheetState();
}

class _AttachProductSheetState extends State<_AttachProductSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _refCtrl;
  late final TextEditingController _packCtrl;
  late final TextEditingController _priceCtrl;
  String? _productId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _refCtrl = TextEditingController();
    _packCtrl = TextEditingController(text: '1');
    _priceCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _packCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_productId == null) return;
    setState(() => _submitting = true);
    try {
      await getIt<SupplierRepository>().attachProduct(
        widget.supplierId,
        productId: _productId!,
        supplierReference:
            _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        packSize: int.tryParse(_packCtrl.text.trim()),
        price: double.tryParse(_priceCtrl.text.trim().replaceAll(',', '.')),
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Produit lié au fournisseur.',
          kind: SnackKind.success);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text('Lier un produit', style: AppTypography.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String?>(
              label: 'Produit *',
              value: _productId,
              options: widget.products
                  .map((p) => AppDropdownOption(value: p.id, label: p.name))
                  .toList(),
              onChanged: (v) => setState(() => _productId = v),
              validator: (v) => v == null ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'Référence fournisseur', controller: _refCtrl),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Conditionnement',
              controller: _packCtrl,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Prix (€)',
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Lier le produit',
              isLoading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
