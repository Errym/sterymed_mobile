import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/formatters/currency_formatter.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/cursor_paginated_list.dart';
import '../../data/models/purchase_order_data.dart';
import '../../data/repositories/purchase_repository.dart';
import '../bloc/purchase_order_list_bloc.dart';
import '../widgets/purchase_order_create_sheet.dart';

class PurchaseOrderListScreen extends StatelessWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PurchaseOrderListBloc(getIt<PurchaseRepository>())
        ..add(const LoadPurchaseOrders()),
      child: const _PoListView(),
    );
  }
}

class _PoListView extends StatelessWidget {
  const _PoListView();

  @override
  Widget build(BuildContext context) {
    final canManage = getIt<SessionStore>().hasPermission('purchasing.manage');
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Commandes & Réceptions',
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nouvelle commande',
              onPressed: () async {
                final ok = await PurchaseOrderCreateSheet.show(context);
                if (ok == true && context.mounted) {
                  context
                      .read<PurchaseOrderListBloc>()
                      .add(const LoadPurchaseOrders());
                }
              },
            ),
        ],
      ),
      body: BlocBuilder<PurchaseOrderListBloc, PurchaseOrderListState>(
        builder: (context, state) {
          if (state.status == PurchaseOrderListStatus.success &&
              state.orders.isEmpty) {
            return EmptyView(
              title: 'Aucune commande',
              message: canManage
                  ? 'Créez votre première commande fournisseur.'
                  : 'Aucune commande fournisseur pour le moment.',
              icon: Icons.shopping_cart_outlined,
              action: canManage
                  ? FilledButton.icon(
                      onPressed: () async {
                        final ok =
                            await PurchaseOrderCreateSheet.show(context);
                        if (ok == true && context.mounted) {
                          context
                              .read<PurchaseOrderListBloc>()
                              .add(const LoadPurchaseOrders());
                        }
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nouvelle commande'),
                    )
                  : null,
            );
          }
          return CursorPaginatedList<PurchaseOrderData>(
            items: state.orders,
            isLoading: state.status == PurchaseOrderListStatus.loading,
            isLoadingMore: state.isLoadingMore,
            hasMore: state.hasMore,
            error: state.status == PurchaseOrderListStatus.failure
                ? (state.error ?? 'Erreur')
                : null,
            onRetry: () => context
                .read<PurchaseOrderListBloc>()
                .add(const LoadPurchaseOrders()),
            onLoadMore: () async => context
                .read<PurchaseOrderListBloc>()
                .add(const LoadMorePurchaseOrders()),
            onRefresh: () async => context
                .read<PurchaseOrderListBloc>()
                .add(const LoadPurchaseOrders()),
            emptyTitle: 'Aucune commande',
            emptyIcon: Icons.shopping_cart_outlined,
            itemBuilder: (_, order, i) => AnimatedListItem(
              index: i,
              child: _PoTile(order: order),
            ),
          );
        },
      ),
    );
  }
}

class _PoTile extends StatelessWidget {
  final PurchaseOrderData order;
  const _PoTile({required this.order});

  /// "50 × Gants nitrile · 20 × Lames de bistouri · +2" — what is in the box.
  String get _contents {
    if (order.lines.isEmpty) return 'Aucune ligne';
    final shown = order.lines
        .take(2)
        .map((l) => '${l.qtyOrdered} × ${l.productName}')
        .join('  ·  ');
    final more = order.lines.length - 2;
    return more > 0 ? '$shown  ·  +$more' : shown;
  }

  /// Units received over units ordered, 0-1. Null before anything is ordered.
  double? get _received {
    final ordered = order.lines.fold<int>(0, (s, l) => s + l.qtyOrdered);
    if (ordered == 0) return null;
    final got = order.lines.fold<int>(0, (s, l) => s + l.qtyReceived);
    return (got / ordered).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final received = _received;
    final showProgress = received != null &&
        (order.status == 'ordered' ||
            order.status == 'partially_received' ||
            order.status == 'received');
    return AppCard(
      onTap: () => context.openRoute(Routes.purchaseDetail(order.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.shortId}  ·  '
                      '${DateFormat('dd/MM/yyyy').format(order.createdAt)}',
                      style: AppTypography.eyebrow,
                    ),
                    const SizedBox(height: 2),
                    Text(order.supplierName, style: AppTypography.cardTitle),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TypeBadge(
                label: _statusLabel(order.status),
                tone: _statusTone(order.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _contents,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (showProgress) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: received,
                minHeight: 6,
                backgroundColor: AppColors.backgroundMuted,
                valueColor: AlwaysStoppedAnimation<Color>(
                  received >= 1 ? AppColors.success : AppColors.warning,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              received >= 1
                  ? 'Tout est reçu'
                  : '${order.qtyRemaining} unité(s) restant à recevoir',
              style: AppTypography.caption,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (order.expectedAt != null &&
                  order.status != 'received' &&
                  order.status != 'cancelled') ...[
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Livraison ${DateFormat('dd/MM/yyyy').format(order.expectedAt!)}',
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
              if (order.totalAmount != null)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      AppCurrencyFormatter.eur(order.totalAmount!),
                      style: AppTypography.metric.copyWith(
                        fontSize: 18,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Backend enum (PurchaseOrderStatus): draft, ordered, partially_received,
  // received, closed, cancelled.
  String _statusLabel(String s) {
    switch (s) {
      case 'draft':
        return 'Brouillon';
      case 'ordered':
        return 'Commandé';
      case 'partially_received':
        return 'Partiel';
      case 'received':
        return 'Reçu';
      case 'closed':
        return 'Clôturé';
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
      case 'partially_received':
        return BadgeTone.orange;
      case 'received':
        return BadgeTone.green;
      case 'closed':
        return BadgeTone.gray;
      case 'cancelled':
        return BadgeTone.gray;
      default:
        return BadgeTone.yellow;
    }
  }
}
