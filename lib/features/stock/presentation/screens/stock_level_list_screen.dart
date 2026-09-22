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
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/models/stock_level_data.dart';
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
                        AnimatedListItem(
                          index: 0,
                          child: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: AppSpacing.sm,
                            mainAxisSpacing: AppSpacing.sm,
                            mainAxisExtent: 100,
                            children: [
                              _countUpKpi(
                                label: 'Références',
                                value: state.totalRefs,
                                icon: Icons.inventory_2_outlined,
                                accent: AppColors.brandPrimary,
                              ),
                              _countUpKpi(
                                label: 'Stock faible',
                                value: state.lowCount,
                                icon: Icons.warning_amber_outlined,
                                accent: AppColors.warning,
                              ),
                              _countUpKpi(
                                label: 'DLC proche',
                                value: state.nearExpiryCount,
                                icon: Icons.timer_outlined,
                                accent: AppColors.info,
                              ),
                              _countUpKpi(
                                label: 'Périmés',
                                value: state.expiredCount,
                                icon: Icons.cancel_outlined,
                                accent: AppColors.danger,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AnimatedListItem(
                          index: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionHeader(title: 'Actions rapides'),
                              Row(
                                children: [
                                  Expanded(
                                    child: _QuickAction(
                                      icon: Icons.remove_circle_outline,
                                      label: 'Sortie',
                                      onTap: () =>
                                          context.go(Routes.stockIssue),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: _QuickAction(
                                      icon: Icons.edit_outlined,
                                      label: 'Ajustement',
                                      onTap: () =>
                                          context.go(Routes.stockAdjust),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: _QuickAction(
                                      icon: Icons.swap_horiz,
                                      label: 'Transfert',
                                      onTap: () =>
                                          context.go(Routes.stockTransfer),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
                      itemBuilder: (_, i) => AnimatedListItem(
                        index: i,
                        child: StockLevelTile(
                          level: state.filtered[i],
                          onTap: () =>
                              _showStockDetail(context, state.filtered[i]),
                        ),
                      ),
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

  Widget _countUpKpi({
    required String label,
    required int value,
    required IconData icon,
    required Color accent,
  }) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => KpiCard(
        label: label,
        value: v.toString(),
        icon: icon,
        accentColor: accent,
      ),
    );
  }

  void _showStockDetail(BuildContext context, StockLevelData level) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(level.productName, style: AppTypography.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            _detailRow(Icons.numbers, 'Référence', level.reference),
            _detailRow(Icons.place_outlined, 'Emplacement', level.locationName),
            _detailRow(Icons.inventory_2_outlined, 'Quantité',
                '${level.qty} ${level.unit}'),
            if (level.batchNumber != null)
              _detailRow(Icons.qr_code, 'Lot', level.batchNumber!),
            if (level.expiryDate != null)
              _detailRow(
                Icons.event_busy_outlined,
                'Expire le',
                '${level.expiryDate!.day.toString().padLeft(2, '0')}/'
                    '${level.expiryDate!.month.toString().padLeft(2, '0')}/'
                    '${level.expiryDate!.year}',
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.label)),
          Text(value, style: AppTypography.bodyStrong),
        ],
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
