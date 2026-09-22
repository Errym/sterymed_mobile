import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../catalog/data/models/product_data.dart';
import '../../../catalog/data/repositories/product_repository.dart';
import '../../../suppliers/data/models/supplier_data.dart';
import '../../../suppliers/data/repositories/supplier_repository.dart';
import '../../data/repositories/purchase_repository.dart';

class PurchaseOrderCreateSheet extends StatefulWidget {
  const PurchaseOrderCreateSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => const PurchaseOrderCreateSheet(),
    );
  }

  @override
  State<PurchaseOrderCreateSheet> createState() =>
      _PurchaseOrderCreateSheetState();
}

class _PoLine {
  ProductData? product;
  int qty = 1;
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final TextEditingController priceCtrl = TextEditingController();

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
  bool _loading = true;
  bool _submitting = false;

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
      setState(() {
        _suppliers = suppliers;
        _products = products;
        _supplierId = suppliers.isNotEmpty ? suppliers.first.id : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

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
    final validLines =
        _lines.where((l) => l.product != null && l.qty > 0).toList();
    if (validLines.isEmpty) {
      AppSnackbar.show(context, 'Ajoutez au moins une ligne valide.',
          kind: SnackKind.warning);
      return;
    }
    setState(() => _submitting = true);
    try {
      final lines = validLines.map((l) {
        final priceStr = l.priceCtrl.text.trim();
        // Always send a numeric value — parse from string first.
        // If empty or invalid, send null (optional field).
        final price = priceStr.isEmpty ? null : double.tryParse(priceStr);
        return {
          'product_id': l.product!.id,
          'qty_ordered': l.qty,
          if (price != null) 'unit_price': price,
        };
      }).toList();

      await getIt<PurchaseRepository>().create(
        supplierId: _supplierId!,
        lines: lines,
      );

      if (!mounted) return;
      AppSnackbar.show(context, 'Commande créée.', kind: SnackKind.success);
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
      child: _loading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : ListView(
              shrinkWrap: true,
              children: [
                const Text('Nouvelle commande',
                    style: AppTypography.sectionTitle),
                const SizedBox(height: AppSpacing.md),
                if (_suppliers.isEmpty || _products.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      _suppliers.isEmpty
                          ? 'Ajoutez d\'abord un fournisseur.'
                          : 'Ajoutez d\'abord un produit dans le catalogue.',
                      style: AppTypography.caption,
                    ),
                  )
                else ...[
                  AppDropdown<String>(
                    label: 'Fournisseur *',
                    value: _supplierId,
                    options: _suppliers
                        .map((s) =>
                            AppDropdownOption(value: s.id, label: s.name))
                        .toList(),
                    onChanged: (v) => setState(() => _supplierId = v),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text('Lignes de commande',
                      style: AppTypography.bodyStrong),
                  const SizedBox(height: AppSpacing.sm),
                  for (int i = 0; i < _lines.length; i++)
                    _LineEditor(
                      key: ValueKey('line_$i'),
                      line: _lines[i],
                      products: _products,
                      canRemove: _lines.length > 1,
                      onChanged: () => setState(() {}),
                      onRemove: () => _removeLine(i),
                    ),
                  TextButton.icon(
                    onPressed: _addLine,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ajouter une ligne'),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Créer la commande',
                  isLoading: _submitting,
                  onPressed: (_suppliers.isEmpty || _products.isEmpty)
                      ? null
                      : _submit,
                ),
              ],
            ),
    );
  }
}

class _LineEditor extends StatelessWidget {
  final _PoLine line;
  final List<ProductData> products;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _LineEditor({
    super.key,
    required this.line,
    required this.products,
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
        color: AppColors.backgroundSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Quantité',
                  controller: line.qtyCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    line.qty = int.tryParse(v) ?? 1;
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
                ),
              ),
              if (canRemove)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.danger, size: 20),
                  onPressed: onRemove,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
