import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/purchase_order_data.dart';
import '../../data/repositories/purchase_repository.dart';

class PurchaseOrderDetailScreen extends StatefulWidget {
  final String poId;
  const PurchaseOrderDetailScreen({super.key, required this.poId});

  @override
  State<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState
    extends State<PurchaseOrderDetailScreen> {
  late Future<PurchaseOrderData> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<PurchaseRepository>().show(widget.poId);
  }

  Future<void> _reload() async {
    setState(() => _future = getIt<PurchaseRepository>().show(widget.poId));
    await _future;
  }

  Future<void> _markOrdered() async {
    try {
      await getIt<PurchaseRepository>().markOrdered(widget.poId);
      if (!mounted) return;
      AppSnackbar.show(context, 'Commande marquée comme envoyée.',
          kind: SnackKind.success);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Commande'),
      body: FutureBuilder<PurchaseOrderData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snap.hasError || !snap.hasData) {
            return ErrorView(
              message: 'Impossible de charger la commande.',
              onRetry: _reload,
            );
          }
          final po = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(po.reference, style: AppTypography.sectionTitle),
                    const SizedBox(height: AppSpacing.xs),
                    Text(po.supplierName, style: AppTypography.caption),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Statut : ${po.status}',
                        style: AppTypography.bodyStrong),
                    const SizedBox(height: 4),
                    Text('${po.lines.length} ligne(s)',
                        style: AppTypography.caption),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Lignes', style: AppTypography.sectionTitle),
              const SizedBox(height: AppSpacing.sm),
              for (final l in po.lines)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(l.productName,
                            style: AppTypography.bodyStrong),
                      ),
                      Text('${l.qtyReceived}/${l.qtyOrdered}',
                          style: AppTypography.bodyStrong),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              if (po.canOrder)
                FilledButton.icon(
                  onPressed: _markOrdered,
                  icon: const Icon(Icons.send),
                  label: const Text('Marquer comme commandée'),
                ),
              if (po.canReceive) ...[
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: () => context.go(Routes.goodsReceipt(po.id)),
                  icon: const Icon(Icons.inbox_outlined),
                  label: const Text('Réceptionner'),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}
