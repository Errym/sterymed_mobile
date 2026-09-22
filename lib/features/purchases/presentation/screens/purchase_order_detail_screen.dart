import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/models/purchase_order_data.dart';
import '../../data/models/purchase_order_line_data.dart';
import '../../data/repositories/purchase_repository.dart';

class PurchaseOrderDetailScreen extends StatefulWidget {
  final String poId;
  const PurchaseOrderDetailScreen({super.key, required this.poId});

  @override
  State<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  late Future<PurchaseOrderData> _future;
  bool _marking = false;

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
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Marquer comme commandée ?',
      message: 'La commande sera envoyée au fournisseur.',
      confirmLabel: 'Confirmer',
    );
    if (!ok || !mounted) return;
    setState(() => _marking = true);
    try {
      await getIt<PurchaseRepository>().markOrdered(widget.poId);
      if (!mounted) return;
      AppSnackbar.show(context, 'Commande marquée comme envoyée.',
          kind: SnackKind.success);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'draft':
        return 'Brouillon';
      case 'ordered':
        return 'Commandé';
      case 'partial':
        return 'Partiel';
      case 'received':
        return 'Reçu';
      case 'cancelled':
        return 'Annulé';
      default:
        return s;
    }
  }

  BadgeTone _statusTone(String s) {
    switch (s) {
      case 'ordered':
        return BadgeTone.blue;
      case 'partial':
        return BadgeTone.orange;
      case 'received':
        return BadgeTone.green;
      case 'cancelled':
        return BadgeTone.gray;
      default:
        return BadgeTone.yellow;
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
          var i = 0;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AnimatedListItem(
                index: i++,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.borderLight),
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(po.reference,
                                style: AppTypography.sectionTitle),
                          ),
                          TypeBadge(
                            label: _statusLabel(po.status),
                            tone: _statusTone(po.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(Icons.local_shipping_outlined,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(po.supplierName, style: AppTypography.caption),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.event_outlined,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yyyy').format(po.createdAt),
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                      if (po.totalAmount != null) ...[
                        const Divider(
                            height: AppSpacing.lg,
                            color: AppColors.borderLight),
                        Row(
                          children: [
                            const Text('Total estimé',
                                style: AppTypography.label),
                            const Spacer(),
                            Text(
                              '${po.totalAmount!.toStringAsFixed(2)} €',
                              style: AppTypography.sectionTitle.copyWith(
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AnimatedListItem(
                index: i++,
                child: SectionHeader(title: 'Lignes (${po.lines.length})'),
              ),
              for (final l in po.lines)
                AnimatedListItem(index: i++, child: _LineTile(line: l)),
              const SizedBox(height: AppSpacing.xl),
              if (po.canOrder)
                AnimatedListItem(
                  index: i++,
                  child: PrimaryButton(
                    label: 'Marquer comme commandée',
                    icon: Icons.send,
                    isLoading: _marking,
                    onPressed: _marking ? null : _markOrdered,
                  ),
                ),
              if (po.canReceive)
                AnimatedListItem(
                  index: i++,
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: PrimaryButton(
                      label: 'Réceptionner',
                      icon: Icons.inbox_outlined,
                      onPressed: () => context.go(Routes.goodsReceipt(po.id)),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  final PurchaseOrderLineData line;
  const _LineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final complete = line.qtyReceived >= line.qtyOrdered;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(line.productName, style: AppTypography.bodyStrong),
              ),
              if (line.unitPrice != null)
                Text(
                  '${line.unitPrice!.toStringAsFixed(2)} €',
                  style: AppTypography.caption,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: line.qtyOrdered == 0
                        ? 0
                        : line.qtyReceived / line.qtyOrdered,
                    minHeight: 6,
                    backgroundColor: AppColors.backgroundMuted,
                    color:
                        complete ? AppColors.success : AppColors.brandPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${line.qtyReceived}/${line.qtyOrdered}',
                style: AppTypography.bodyStrong.copyWith(
                  color: complete ? AppColors.success : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
