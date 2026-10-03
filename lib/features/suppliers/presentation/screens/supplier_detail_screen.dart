import 'package:flutter/material.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/decimal_input.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/formatters/currency_formatter.dart';
import '../../../../core/utils/formatters/date_formatter.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../catalog/data/models/product_data.dart';
import '../../../catalog/data/repositories/product_repository.dart';
import '../../../purchases/data/models/purchase_order_data.dart';
import '../../../purchases/data/repositories/purchase_repository.dart';
import '../../data/models/supplier_data.dart';
import '../../data/models/supplier_order_stats.dart';
import '../../data/models/supplier_product_data.dart';
import '../../data/repositories/supplier_repository.dart';
import '../widgets/supplier_form_sheet.dart';

class SupplierDetailScreen extends StatefulWidget {
  final String supplierId;
  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

/// Everything the page needs, read together.
class _SupplierPage {
  final SupplierData supplier;
  final List<SupplierProductData> links;
  final Map<String, ProductData> productsById;

  /// This supplier's orders among the most recent ones. Null when the order
  /// list could not be read (the page still works without it).
  final List<PurchaseOrderData>? orders;
  const _SupplierPage(this.supplier, this.links, this.productsById, this.orders);
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  late Future<_SupplierPage> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SupplierPage> _load() async {
    final results = await Future.wait([
      getIt<SupplierRepository>().show(widget.supplierId),
      getIt<SupplierRepository>()
          .listProducts(widget.supplierId, forceRefresh: true),
      getIt<ProductRepository>().list(),
    ]);
    List<PurchaseOrderData>? orders;
    try {
      final page = await getIt<PurchaseRepository>().list(forceRefresh: true);
      orders = page.items.where((o) => o.supplierId == widget.supplierId).toList();
    } catch (_) {
      orders = null;
    }
    final products = results[2] as List<ProductData>;
    return _SupplierPage(
      results[0] as SupplierData,
      results[1] as List<SupplierProductData>,
      {for (final p in products) p.id: p},
      orders,
    );
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
      body: FutureBuilder<_SupplierPage>(
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
          final page = snap.data;
          if (page == null) return const LoadingView();
          final supplier = page.supplier;
          final links = page.links;
          final orders = page.orders;
          final stats = orders == null
              ? null
              : SupplierOrderStats.bySupplier(orders)[supplier.id] ??
                  const SupplierOrderStats();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                AnimatedListItem(
                  index: 0,
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            EntityMark.initials(
                              EntityMark.initialsOf(supplier.name),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'FOURNISSEUR',
                                    style: AppTypography.eyebrow,
                                  ),
                                  Text(
                                    supplier.name,
                                    style: AppTypography.sectionTitle,
                                  ),
                                ],
                              ),
                            ),
                            if (canManage)
                              IconButton(
                                tooltip: 'Modifier',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () async {
                                  final saved = await SupplierFormSheet.show(
                                    context,
                                    existing: supplier,
                                  );
                                  if (saved == true) await _refresh();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ContactActions(
                          phone: supplier.phone,
                          email: supplier.email,
                          address: supplier.address,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DetailRow(Icons.call_outlined, 'Téléphone',
                            _orDash(supplier.phone)),
                        DetailRow(Icons.mail_outline, 'E-mail',
                            _orDash(supplier.email)),
                        DetailRow(Icons.place_outlined, 'Adresse',
                            _orDash(supplier.address)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AnimatedListItem(
                  index: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: _Figure(
                          label: 'Produits fournis',
                          value: '${links.length}',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _Figure(
                          label: 'Commandes en cours',
                          value: stats == null ? '—' : '${stats.open}',
                          color: (stats?.open ?? 0) > 0
                              ? AppColors.warning
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _Figure(
                          label: 'Dernière commande',
                          value: stats?.lastOrderedAt == null
                              ? '—'
                              : AppDateFormatter.date(stats!.lastOrderedAt!),
                          small: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'PRODUITS FOURNIS (${links.length})',
                        style: AppTypography.eyebrow,
                      ),
                    ),
                    if (canManage)
                      TextButton.icon(
                        onPressed: () =>
                            _addProduct(page.productsById.values.toList()),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Lier un produit'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                if (links.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      canManage
                          ? 'Aucun produit lié. Liez les produits que ce '
                              'fournisseur peut livrer.'
                          : 'Aucun produit n\'est encore lié à ce fournisseur.',
                      style: AppTypography.caption,
                    ),
                  )
                else
                  for (var i = 0; i < links.length; i++)
                    AnimatedListItem(
                      index: i + 2,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _SupplierProductTile(
                          link: links[i],
                          product: page.productsById[links[i].productId],
                        ),
                      ),
                    ),
                if (orders != null && orders.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(title: 'Commandes récentes'),
                  for (final o in orders.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _OrderRow(order: o),
                    ),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _orDash(String? v) =>
      (v == null || v.trim().isEmpty) ? '—' : v.trim();
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool small;
  const _Figure({
    required this.label,
    required this.value,
    this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.metric.copyWith(
                fontSize: small ? 15 : 22,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.caption.copyWith(fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
    return EntityCard(
      mark: const EntityMark.icon(Icons.inventory_2_outlined),
      eyebrow: link.supplierReference == null
          ? null
          : 'RÉF. FOURNISSEUR ${link.supplierReference}',
      title: product?.name ?? 'Produit inconnu',
      trailing: link.price == null
          ? null
          : Text(
              AppCurrencyFormatter.eur(link.price!),
              style: AppTypography.metric.copyWith(
                fontSize: 17,
                color: AppColors.brandPrimary,
              ),
            ),
      tags: [
        InfoTag('Conditionnement ×${link.packSize}',
            icon: Icons.widgets_outlined),
        if (product != null) InfoTag('Unité : ${product!.unit}'),
        if (product != null && product!.reference.isNotEmpty)
          InfoTag('Réf. ${product!.reference}', icon: Icons.tag),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  final PurchaseOrderData order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (order.status) {
      'ordered' => ('Commandé', BadgeTone.blue),
      'partially_received' => ('Partiel', BadgeTone.orange),
      'received' => ('Reçu', BadgeTone.green),
      'cancelled' => ('Annulé', BadgeTone.gray),
      'closed' => ('Clôturé', BadgeTone.gray),
      _ => ('Brouillon', BadgeTone.yellow),
    };
    return AppCard(
      onTap: () => context.openRoute(Routes.purchaseDetail(order.id)),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.shortId, style: AppTypography.bodyStrong),
                Text(
                  '${order.lines.length} ligne(s) · '
                  '${AppDateFormatter.date(order.orderedAt ?? order.createdAt)}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          if (order.totalAmount != null) ...[
            Text(
              AppCurrencyFormatter.eur(order.totalAmount!),
              style: AppTypography.bodyStrong,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          TypeBadge(label: label, tone: tone),
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
    return showAppSheet<bool>(
      context,
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
        price: DecimalInput.parse(_priceCtrl.text, maxDecimals: 4),
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Produit lié au fournisseur.',
          kind: SnackKind.success);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
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
              validator: (v) => DecimalInput.isInvalid(v, maxDecimals: 4)
                  ? DecimalInput.invalidMessage
                  : null,
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
