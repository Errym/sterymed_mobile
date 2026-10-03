import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/decimal_input.dart';
import '../../../../core/utils/formatters/currency_formatter.dart';
import '../../../../core/utils/formatters/date_formatter.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../catalog/data/models/product_data.dart';
import '../../../catalog/data/repositories/product_repository.dart';
import '../../../suppliers/data/models/supplier_product_data.dart';
import '../../../suppliers/data/models/supplier_data.dart';
import '../../../suppliers/data/repositories/supplier_repository.dart';
import '../../data/models/purchase_order_data.dart';
import '../../data/repositories/purchase_repository.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/inputs/app_date_picker.dart';

/// Creates an order, or (when [editing] is given) edits a draft: same form,
/// same rules. The supplier of an existing draft stays fixed; to change it,
/// cancel the draft and start a new order.
class PurchaseOrderCreateSheet extends StatefulWidget {
  final PurchaseOrderData? editing;

  const PurchaseOrderCreateSheet({super.key, this.editing});

  static Future<bool?> show(BuildContext context, {PurchaseOrderData? editing}) {
    return showAppSheet<bool>(
      context,
      builder: (_) => PurchaseOrderCreateSheet(editing: editing),
    );
  }

  @override
  State<PurchaseOrderCreateSheet> createState() =>
      _PurchaseOrderCreateSheetState();
}

class _PoLine {
  _PoLine({this.product, this.qty = 1, String price = ''})
    : qtyCtrl = TextEditingController(text: '$qty'),
      priceCtrl = TextEditingController(text: price);

  ProductData? product;
  int qty;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _PurchaseOrderCreateSheetState extends State<PurchaseOrderCreateSheet> {
  List<SupplierData> _suppliers = [];
  List<ProductData> _products = [];
  String? _supplierId;
  final List<_PoLine> _lines = [_PoLine()];
  DateTime? _expectedAt;
  bool _loading = true;
  bool _submitting = false;

  /// What the chosen supplier sells, by product: its price and pack size. Used
  /// to pre-fill a line's price; absent means the person types it.
  Map<String, SupplierProductData> _links = {};

  PurchaseOrderData? get _editing => widget.editing;

  Future<void> _loadLinks(String? supplierId) async {
    if (supplierId == null) {
      setState(() => _links = {});
      return;
    }
    try {
      final links = await getIt<SupplierRepository>()
          .listProducts(supplierId, forceRefresh: true);
      if (!mounted || _supplierId != supplierId) return;
      setState(() => _links = {for (final l in links) l.productId: l});
    } catch (_) {
      if (mounted) setState(() => _links = {});
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final suppliers =
          await getIt<SupplierRepository>().list(forceRefresh: true);
      final products =
          await getIt<ProductRepository>().list(forceRefresh: true);
      if (!mounted) return;
      final editing = _editing;
      setState(() {
        _suppliers = suppliers;
        _products = products;
        if (editing != null) {
          // The draft's own values, not the first supplier of the list.
          _supplierId = editing.supplierId;
          _expectedAt = editing.expectedAt;
          for (final l in _lines) {
            l.dispose();
          }
          _lines
            ..clear()
            ..addAll(
              editing.lines.map((l) {
                final matches = products.where((p) => p.id == l.productId);
                return _PoLine(
                  product: matches.isEmpty ? null : matches.first,
                  qty: l.qtyOrdered,
                  price: l.unitPrice == null
                      ? ''
                      : l.unitPrice!.toStringAsFixed(2).replaceAll('.', ','),
                );
              }),
            );
        } else {
          _supplierId = suppliers.isNotEmpty ? suppliers.first.id : null;
        }
        _loading = false;
      });
      _loadLinks(_supplierId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  double? _lineTotal(_PoLine l) {
    final price = DecimalInput.parse(l.priceCtrl.text, maxDecimals: 4);
    if (price == null || l.product == null || l.qty <= 0) return null;
    return price * l.qty;
  }

  double get _total =>
      _lines.fold<double>(0, (s, l) => s + (_lineTotal(l) ?? 0));

  int get _units => _lines
      .where((l) => l.product != null && l.qty > 0)
      .fold<int>(0, (s, l) => s + l.qty);

  void _addLine() {
    setState(() => _lines.add(_PoLine()));
  }

  void _removeLine(int i) {
    if (_lines.length <= 1) return;
    _lines[i].dispose();
    setState(() => _lines.removeAt(i));
  }

  Future<void> _submit() async {
    if (_supplierId == null) {
      AppSnackbar.show(context, 'Sélectionnez un fournisseur.',
          kind: SnackKind.warning);
      return;
    }
    // A half-filled line is an error to fix, not something to drop silently.
    if (_lines.any((l) => l.product != null && l.qty <= 0)) {
      AppSnackbar.show(
        context,
        'Une ligne a une quantité nulle : corrigez-la ou supprimez-la.',
        kind: SnackKind.warning,
      );
      return;
    }
    final productIds = _lines.map((l) => l.product?.id).whereType<String>();
    if (productIds.length != productIds.toSet().length) {
      AppSnackbar.show(
        context,
        'Un même produit apparaît sur deux lignes : regroupez-les.',
        kind: SnackKind.warning,
      );
      return;
    }
    final validLines =
        _lines.where((l) => l.product != null && l.qty > 0).toList();
    if (validLines.isEmpty) {
      AppSnackbar.show(context, 'Ajoutez au moins une ligne valide.',
          kind: SnackKind.warning);
      return;
    }
    if (validLines.any(
      (l) => DecimalInput.isInvalid(l.priceCtrl.text, maxDecimals: 4),
    )) {
      AppSnackbar.show(
        context,
        'Un prix unitaire est invalide (ex. 12,50).',
        kind: SnackKind.warning,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final lines = validLines.map((l) {
        final priceStr = l.priceCtrl.text.trim();
        // Always send a numeric value — parse from string first.
        // If empty or invalid, send null (optional field).
        final price = DecimalInput.parse(priceStr, maxDecimals: 4);
        return {
          'product_id': l.product!.id,
          'qty_ordered': l.qty,
          if (price != null) 'unit_price': price,
        };
      }).toList();

      final editing = _editing;
      if (editing == null) {
        await getIt<PurchaseRepository>().create(
          supplierId: _supplierId!,
          lines: lines,
          expectedAt: _expectedAt,
        );
      } else {
        await getIt<PurchaseRepository>().update(
          editing.id,
          lines: lines,
          expectedAt: _expectedAt,
          clearExpectedAt: _expectedAt == null && editing.expectedAt != null,
        );
      }

      if (!mounted) return;
      AppSnackbar.show(
        context,
        editing == null ? 'Commande créée.' : 'Commande modifiée.',
        kind: SnackKind.success,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _preview() {
    String name = 'Choisir un fournisseur';
    for (final s in _suppliers) {
      if (s.id == _supplierId) name = s.name;
    }
    final total = _total;
    final lines = _lines.where((l) => l.product != null).length;
    return PreviewCard(
      key: const Key('order-preview'),
      mark: EntityMark.initials(
        _supplierId == null ? '•' : EntityMark.initialsOf(name),
      ),
      eyebrow: _editing == null ? 'NOUVELLE COMMANDE' : 'BROUILLON',
      title: name,
      titleIsPlaceholder: _supplierId == null,
      tags: [
        InfoTag('$lines ligne${lines > 1 ? 's' : ''}', icon: Icons.list_alt),
        if (_units > 0) InfoTag('$_units unités', icon: Icons.inventory_2_outlined),
        if (total > 0)
          InfoTag(AppCurrencyFormatter.eur(total),
              icon: Icons.euro, color: AppColors.brandPrimary),
        if (_expectedAt != null)
          InfoTag(AppDateFormatter.date(_expectedAt!),
              icon: Icons.local_shipping_outlined),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final blocked = _suppliers.isEmpty || _products.isEmpty;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              children: [
                const SheetHandle(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _editing == null ? 'Nouvelle commande' : 'Modifier la commande',
                  style: AppTypography.sectionTitle,
                ),
                const SizedBox(height: 2),
                Text(
                  _editing == null
                      ? 'La commande reste un brouillon jusqu\'à ce que vous '
                          'la marquiez comme commandée.'
                      : 'Seul un brouillon peut être modifié.',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpacing.md),
                if (blocked)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Text(
                      _suppliers.isEmpty
                          ? 'Ajoutez d\'abord un fournisseur.'
                          : 'Ajoutez d\'abord un produit dans le catalogue.',
                      style: AppTypography.caption,
                    ),
                  )
                else ...[
                  _preview(),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Fournisseur',
                    trailing:
                        const Text('Requis', style: AppTypography.caption),
                    children: [
                      AppDropdown<String>(
                        label: 'Fournisseur *',
                        value: _supplierId,
                        options: _suppliers
                            .map((s) =>
                                AppDropdownOption(value: s.id, label: s.name))
                            .toList(),
                        // A draft keeps its supplier; changing it means a new
                        // order.
                        enabled: _editing == null,
                        onChanged: (v) {
                          setState(() => _supplierId = v);
                          _loadLinks(v);
                        },
                      ),
                      if (_links.isNotEmpty)
                        Text(
                          '${_links.length} produit(s) de ce fournisseur ont '
                          'un prix enregistré : il est proposé automatiquement.',
                          style: AppTypography.caption,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Livraison',
                    trailing:
                        const Text('Facultatif', style: AppTypography.caption),
                    children: [
                      AppDatePicker(
                        label: 'Livraison prévue (optionnel)',
                        value: _expectedAt,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(DateTime.now().year + 3),
                        onChanged: (d) => setState(() => _expectedAt = d),
                      ),
                      if (_expectedAt != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => setState(() => _expectedAt = null),
                            child: const Text('Retirer la date'),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Lignes de commande',
                    children: [
                      for (int i = 0; i < _lines.length; i++)
                        _LineEditor(
                          key: ValueKey('line_$i'),
                          line: _lines[i],
                          products: _products,
                          link: _links[_lines[i].product?.id],
                          subtotal: _lineTotal(_lines[i]),
                          canRemove: _lines.length > 1,
                          onChanged: () => setState(() {}),
                          onRemove: () => _removeLine(i),
                        ),
                      TextButton.icon(
                        onPressed: _addLine,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Ajouter une ligne'),
                      ),
                      if (_total > 0)
                        StatStrip(
                          icon: Icons.euro,
                          label: 'Total estimé · $_units unités',
                          value: Text(
                            AppCurrencyFormatter.eur(_total),
                            style: AppTypography.bodyStrong.copyWith(
                              color: AppColors.brandPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          PinnedFooter(
            child: PrimaryButton(
              label: _editing == null
                  ? 'Créer la commande'
                  : 'Enregistrer les modifications',
              isLoading: _submitting,
              onPressed: (blocked || _submitting) ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineEditor extends StatelessWidget {
  final _PoLine line;
  final List<ProductData> products;
  final SupplierProductData? link;
  final double? subtotal;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _LineEditor({
    super.key,
    required this.line,
    required this.products,
    required this.link,
    required this.subtotal,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceWell,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppDropdown<String>(
            label: 'Produit *',
            value: line.product?.id,
            options: products
                .map((p) => AppDropdownOption(
                    value: p.id, label: '${p.name} (${p.reference})'))
                .toList(),
            onChanged: (v) {
              line.product = products.firstWhere((p) => p.id == v);
              onChanged();
            },
          ),
          if (link != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (link!.supplierReference != null)
                  'Réf. fournisseur ${link!.supplierReference}',
                'Conditionnement ×${link!.packSize}',
                if (link!.price != null)
                  'Prix catalogue ${AppCurrencyFormatter.eur(link!.price!)}',
              ].join(' · '),
              style: AppTypography.caption,
            ),
            if (link!.price != null && line.priceCtrl.text.trim().isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('use_catalog_price'),
                  onPressed: () {
                    line.priceCtrl.text =
                        link!.price!.toStringAsFixed(2).replaceAll('.', ',');
                    onChanged();
                  },
                  child: const Text('Utiliser le prix catalogue'),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Quantité',
                  controller: line.qtyCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    line.qty = int.tryParse(v) ?? 1;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  label: 'Prix unitaire (€)',
                  controller: line.priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              if (canRemove)
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.danger, size: 20),
                    onPressed: onRemove,
                  ),
                ),
            ],
          ),
          if (subtotal != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Sous-total ${AppCurrencyFormatter.eur(subtotal!)}',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
