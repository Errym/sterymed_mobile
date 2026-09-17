import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/cards/kpi_card.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../data/repositories/stock_repository.dart';
import '../bloc/stock_level_list_bloc.dart';
import '../widgets/stock_level_tile.dart';

class StockLevelListScreen extends StatelessWidget {
  const StockLevelListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StockLevelListBloc(getIt<StockRepository>())
        ..add(const LoadStockLevels()),
      child: const _StockLevelView(),
    );
  }
}

class _StockLevelView extends StatelessWidget {
  const _StockLevelView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Stock & Stérilisation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.go(Routes.alerts),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context
                .read<StockLevelListBloc>()
                .add(const RefreshStockLevels()),
          ),
        ],
      ),
      body: BlocBuilder<StockLevelListBloc, StockLevelListState>(
        builder: (context, state) {
          if (state.status == StockLevelStatus.loading &&
              state.levels.isEmpty) {
            return const LoadingView(message: 'Chargement du stock...');
          }
          if (state.status == StockLevelStatus.failure &&
              state.levels.isEmpty) {
            return ErrorView(
              message: state.error ?? 'Erreur',
              onRetry: () => context
                  .read<StockLevelListBloc>()
                  .add(const LoadStockLevels()),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => context
                .read<StockLevelListBloc>()
                .add(const RefreshStockLevels()),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tableau de bord des stocks',
                            style: AppTypography.pageTitle),
                        const SizedBox(height: AppSpacing.md),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisSpacing: AppSpacing.sm,
                          mainAxisExtent: 100,
                          children: [
                            KpiCard(
                              label: 'Références',
                              value: state.totalRefs.toString(),
                              icon: Icons.inventory_2_outlined,
                            ),
                            KpiCard(
                              label: 'Stock faible',
                              value: state.lowCount.toString(),
                              icon: Icons.warning_amber_outlined,
                            ),
                            KpiCard(
                              label: 'DLC proche',
                              value: state.nearExpiryCount.toString(),
                              icon: Icons.timer_outlined,
                            ),
                            KpiCard(
                              label: 'Périmés',
                              value: state.expiredCount.toString(),
                              icon: Icons.cancel_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const SectionHeader(title: 'Actions rapides'),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.remove_circle_outline,
                                label: 'Sortie',
                                onTap: () => context.go(Routes.stockIssue),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.edit_outlined,
                                label: 'Ajustement',
                                onTap: () => context.go(Routes.stockAdjust),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.swap_horiz,
                                label: 'Transfert',
                                onTap: () => context.go(Routes.stockTransfer),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const SectionHeader(title: 'Catalogue'),
                        AppSearchField(
                          hint: 'Rechercher un produit, lot...',
                          onChanged: (q) => context
                              .read<StockLevelListBloc>()
                              .add(SearchStockLevels(q)),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ),
                  ),
                ),
                if (state.filtered.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      title: 'Aucun produit',
                      message: 'Le catalogue est vide.',
                      icon: Icons.inventory_2_outlined,
                    ),
                  )
                else
                  SliverPadding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    sliver: SliverList.separated(
                      itemCount: state.filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) =>
                          StockLevelTile(level: state.filtered[i]),
                    ),
                  ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xxl)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 18, color: AppColors.brandPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(label,
                  style: AppTypography.caption, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
