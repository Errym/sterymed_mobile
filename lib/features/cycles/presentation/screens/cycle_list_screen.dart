import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../../../shared/widgets/inputs/filter_chip_row.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/cursor_paginated_list.dart';
import '../../../../shared/widgets/lists/list_tile_skeleton.dart';
import '../../data/models/cycle_data.dart';
import '../bloc/cycle_list_bloc.dart';

class CycleListScreen extends StatelessWidget {
  const CycleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => CycleListBloc(ctx.read())..add(const LoadCycles()),
      child: const _CycleListView(),
    );
  }
}

class _CycleListView extends StatelessWidget {
  const _CycleListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Cycles de Stérilisation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: () =>
                context.read<CycleListBloc>().add(const RefreshCycles()),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton.icon(
              onPressed: () => context.go(Routes.cyclesCreate),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nouveau Cycle'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: AppSearchField(
              hint: 'Rechercher cycle par ID, lot, autoclave...',
              onChanged: (v) =>
                  context.read<CycleListBloc>().add(SearchCycles(v)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          BlocBuilder<CycleListBloc, CycleListState>(
            builder: (context, state) {
              return FilterChipRow<String?>(
                selected: state.selectedStatus,
                onSelected: (v) =>
                    context.read<CycleListBloc>().add(FilterCycles(v)),
                options: const [
                  FilterChipOption(value: null, label: 'Tous les cycles'),
                  FilterChipOption(value: 'in_progress', label: 'En cours'),
                  FilterChipOption(
                      value: 'awaiting_release', label: 'Attente Libération'),
                  FilterChipOption(value: 'released', label: 'Conformes'),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: BlocBuilder<CycleListBloc, CycleListState>(
              builder: (context, state) {
                if (state.status == CycleListStatus.loading &&
                    state.cycles.isEmpty) {
                  return const ListSkeleton();
                }
                return CursorPaginatedList<CycleData>(
                  items: state.filtered,
                  hasMore: state.hasMore,
                  isLoadingMore: state.isLoadingMore,
                  error: state.status == CycleListStatus.failure
                      ? (state.error ?? 'Erreur')
                      : null,
                  onRetry: () =>
                      context.read<CycleListBloc>().add(const LoadCycles()),
                  onLoadMore: () async =>
                      context.read<CycleListBloc>().add(const LoadMoreCycles()),
                  onRefresh: () async =>
                      context.read<CycleListBloc>().add(const RefreshCycles()),
                  emptyTitle: 'Aucun cycle',
                  emptyMessage: 'Créez un nouveau cycle de stérilisation.',
                  emptyIcon: Icons.autorenew,
                  itemBuilder: (_, c, i) => AnimatedListItem(
                    index: i,
                    child: _CycleCard(
                      cycle: c,
                      onTap: () => context.go(Routes.cyclesDetail(c.id)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleCard extends StatelessWidget {
  final CycleData cycle;
  final VoidCallback onTap;

  const _CycleCard({required this.cycle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
              // ── Row 1: cycle number + status ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cycle #${cycle.number}',
                      style: AppTypography.bodyStrong,
                    ),
                  ),
                  _statusBadgeFor(cycle.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // ── Row 2: device + programme ──
              Row(
                children: [
                  const Icon(
                    Icons.precision_manufacturing_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      cycle.deviceName,
                      style: AppTypography.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (cycle.programName != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(
                      Icons.thermostat_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        cycle.programName!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // ── Row 3: date + chevron ──
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(cycle.createdAt),
                    style: AppTypography.caption,
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadgeFor(String status) {
    switch (status) {
      case 'released':
        return const TypeBadge(
            label: 'Libéré / Conforme', tone: BadgeTone.green);
      case 'in_progress':
        return const TypeBadge(
            label: 'En cours de cycle', tone: BadgeTone.blue);
      case 'awaiting_release':
        return const TypeBadge(
            label: 'Contrôles saisis', tone: BadgeTone.yellow);
      case 'rejected':
        return const TypeBadge(label: 'Rejeté', tone: BadgeTone.red);
      case 'completed':
        return const TypeBadge(
            label: 'Terminé', tone: BadgeTone.orange);
      default:
        return const TypeBadge(label: 'Créé', tone: BadgeTone.gray);
    }
  }
}
