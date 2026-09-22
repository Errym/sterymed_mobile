import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
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
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Commandes & Réceptions',
        actions: [
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
          if (state.status == PurchaseOrderListStatus.loading &&
              state.orders.isEmpty) {
            return const LoadingView();
          }
          if (state.status == PurchaseOrderListStatus.failure &&
              state.orders.isEmpty) {
            return ErrorView(
              message: state.error ?? 'Erreur',
              onRetry: () => context
                  .read<PurchaseOrderListBloc>()
                  .add(const LoadPurchaseOrders()),
            );
          }
          if (state.orders.isEmpty) {
            return EmptyView(
              title: 'Aucune commande',
              message: 'Créez votre première commande fournisseur.',
              icon: Icons.shopping_cart_outlined,
              action: FilledButton.icon(
                onPressed: () async {
                  final ok = await PurchaseOrderCreateSheet.show(context);
                  if (ok == true && context.mounted) {
                    context
                        .read<PurchaseOrderListBloc>()
                        .add(const LoadPurchaseOrders());
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouvelle commande'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => context
                .read<PurchaseOrderListBloc>()
                .add(const LoadPurchaseOrders()),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: state.orders.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => AnimatedListItem(
                index: i,
                child: _PoTile(order: state.orders[i]),
              ),
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(Routes.purchaseDetail(order.id)),
        borderRadius: BorderRadius.circular(AppRadius.card),
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
              Row(
                children: [
                  Expanded(
                    child:
                        Text(order.reference, style: AppTypography.bodyStrong),
                  ),
                  TypeBadge(
                    label: _statusLabel(order.status),
                    tone: _statusTone(order.status),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(order.supplierName, style: AppTypography.caption),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text('${order.lines.length} ligne(s)',
                      style: AppTypography.caption),
                  const Spacer(),
                  if (order.totalAmount != null)
                    Text(
                      '${order.totalAmount!.toStringAsFixed(2)} €',
                      style: AppTypography.bodyStrong
                          .copyWith(color: AppColors.brandPrimary),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(DateFormat('dd/MM/yy').format(order.createdAt),
                      style: AppTypography.caption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
}
