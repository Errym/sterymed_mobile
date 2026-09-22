import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../stock/data/models/stock_option.dart';
import '../../../stock/data/repositories/stock_repository.dart';
import '../../data/models/purchase_order_data.dart';
import '../../data/repositories/purchase_repository.dart';

class GoodsReceiptScreen extends StatefulWidget {
  final String poId;
  const GoodsReceiptScreen({super.key, required this.poId});

  @override
  State<GoodsReceiptScreen> createState() => _GoodsReceiptScreenState();
}

class _GoodsReceiptScreenState extends State<GoodsReceiptScreen> {
  PurchaseOrderData? _po;
  final Map<String, TextEditingController> _qtyCtrls = {};
  final Map<String, TextEditingController> _batchCtrls = {};
  List<StockOption> _locations = [];
  String? _locationId;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    for (final c in _batchCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        getIt<PurchaseRepository>().show(widget.poId),
        getIt<StockRepository>().listOptions(),
      ]);
      final po = results[0] as PurchaseOrderData;
      final options = results[1] as ({
        List<StockOption> batches,
        List<StockOption> locations
      });
      for (final l in po.lines) {
        _qtyCtrls[l.id] = TextEditingController(text: '${l.qtyRemaining}');
        _batchCtrls[l.id] = TextEditingController();
      }
      if (!mounted) return;
      setState(() {
        _po = po;
        _locations = options.locations;
        _locationId =
            options.locations.isNotEmpty ? options.locations.first.id : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_po == null) return;
    if (_locationId == null) {
      AppSnackbar.show(context, 'Sélectionnez l\'emplacement.',
          kind: SnackKind.warning);
      return;
    }
    setState(() => _submitting = true);
    try {
      final lines = _po!.lines
          .map((l) {
            final qty = int.tryParse(_qtyCtrls[l.id]?.text.trim() ?? '') ?? 0;
            final batch = _batchCtrls[l.id]?.text.trim() ?? '';
            return {
              'purchase_order_line_id': l.id,
              'batch_number': batch.isEmpty
                  ? 'BATCH-${DateTime.now().millisecondsSinceEpoch}'
                  : batch,
              'qty': qty,
            };
          })
          .where((m) => (m['qty'] as int) > 0)
          .toList();

      if (lines.isEmpty) {
        AppSnackbar.show(context, 'Aucune quantité saisie.',
            kind: SnackKind.warning);
        setState(() => _submitting = false);
        return;
      }

      await getIt<PurchaseRepository>().receive(
        poId: widget.poId,
        locationId: _locationId!,
        lines: lines,
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Réception enregistrée.',
          kind: SnackKind.success);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Réception marchandise'),
      body: _loading
          ? const LoadingView()
          : _po == null
              ? const ErrorView(message: 'Commande introuvable.')
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    AnimatedListItem(
                      index: 0,
                      child: _locations.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.warningLight,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: const Text(
                                'Aucun emplacement disponible. Réceptionnez '
                                'un premier mouvement de stock pour en créer '
                                'un.',
                                style: AppTypography.caption,
                              ),
                            )
                          : AppDropdown<String>(
                              label: 'Emplacement de réception *',
                              value: _locationId,
                              options: _locations
                                  .map((l) => AppDropdownOption(
                                      value: l.id, label: l.label))
                                  .toList(),
                              onChanged: (v) => setState(() => _locationId = v),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const AnimatedListItem(
                      index: 1,
                      child: Text('Lignes à réceptionner',
                          style: AppTypography.sectionTitle),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (var i = 0; i < _po!.lines.length; i++) ...[
                      AnimatedListItem(
                        index: i + 2,
                        child: Builder(builder: (context) {
                          final l = _po!.lines[i];
                          return Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundCard,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.productName,
                                    style: AppTypography.bodyStrong),
                                const SizedBox(height: 4),
                                Text('Commandé : ${l.qtyOrdered}',
                                    style: AppTypography.caption),
                                const SizedBox(height: AppSpacing.sm),
                                AppTextField(
                                  label: 'Quantité reçue',
                                  controller: _qtyCtrls[l.id],
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                AppTextField(
                                  label: 'Numéro de lot',
                                  controller: _batchCtrls[l.id],
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: 'Valider la réception',
                      isLoading: _submitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
    );
  }
}
