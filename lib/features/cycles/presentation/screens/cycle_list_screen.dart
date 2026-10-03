import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
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
    final canManage = getIt<SessionStore>().hasPermission('cycles.manage');
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Cycles',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: () =>
                context.read<CycleListBloc>().add(const RefreshCycles()),
          ),
          if (canManage)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilledButton.icon(
                onPressed: () => context.openRoute(Routes.cyclesCreate),
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
          const _Pipeline(),
          const SizedBox(height: AppSpacing.sm),
          BlocBuilder<CycleListBloc, CycleListState>(
            builder: (context, state) {
              int count(String s) =>
                  state.cycles.where((c) => c.status == s).length;
              return FilterChipRow<String?>(
                selected: state.selectedStatus,
                onSelected: (v) =>
                    context.read<CycleListBloc>().add(FilterCycles(v)),
                options: [
                  FilterChipOption(
                    value: null,
                    label: 'Tous les cycles (${state.cycles.length})',
                  ),
                  FilterChipOption(
                    value: 'created',
                    label: 'En préparation (${count('created')})',
                  ),
                  FilterChipOption(
                    value: 'in_progress',
                    label: 'En cours (${count('in_progress')})',
                  ),
                  FilterChipOption(
                    value: 'awaiting_release',
                    label: 'Attente Libération (${count('awaiting_release')})',
                  ),
                  FilterChipOption(
                    value: 'released',
                    label: 'Conformes (${count('released')})',
                  ),
                  if (count('rejected') > 0)
                    FilterChipOption(
                      value: 'rejected',
                      label: 'Rejetés (${count('rejected')})',
                    ),
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
                      onTap: () => context.openRoute(Routes.cyclesDetail(c.id)),
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

/// Where the loaded cycles stand, as the sterilization flow reads: running,
/// waiting for a decision, released. A tap filters the list to that stage.
class _Pipeline extends StatelessWidget {
  const _Pipeline();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CycleListBloc, CycleListState>(
      buildWhen: (a, b) => a.cycles != b.cycles,
      builder: (context, state) {
        if (state.cycles.isEmpty) return const SizedBox.shrink();
        int n(String s) => state.cycles.where((c) => c.status == s).length;
        final stages = [
          (
            'Préparation',
            n('created'),
            'created',
            AppColors.textSecondary,
          ),
          ('En cours', n('in_progress'), 'in_progress', AppColors.info),
          (
            'À libérer',
            n('awaiting_release') + n('completed'),
            'awaiting_release',
            AppColors.warning,
          ),
          ('Libérés', n('released'), 'released', AppColors.success),
        ];
        return Padding(
          key: const Key('cycle-pipeline'),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              for (var i = 0; i < stages.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    onTap: () => context
                        .read<CycleListBloc>()
                        .add(FilterCycles(stages[i].$3)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: stages[i].$4.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(AppRadius.control),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${stages[i].$2}',
                            style: AppTypography.kpiNumber.copyWith(
                              color: stages[i].$2 == 0
                                  ? AppColors.textTertiary
                                  : AppColors.text(stages[i].$4),
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            stages[i].$1,
                            style: AppTypography.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CycleCard extends StatelessWidget {
  final CycleData cycle;
  final VoidCallback onTap;

  const _CycleCard({required this.cycle, required this.onTap});

  /// "il y a 12 min" / "il y a 3 h" / the date, for a cycle that has started.
  String? _startedAgo() {
    final s = cycle.startedAt;
    if (s == null) return null;
    final d = DateTime.now().difference(s);
    if (d.inMinutes < 1) return 'Démarré à l\'instant';
    if (d.inMinutes < 60) return 'Démarré il y a ${d.inMinutes} min';
    if (d.inHours < 24) return 'Démarré il y a ${d.inHours} h';
    return 'Démarré le ${DateFormat('dd/MM/yyyy HH:mm').format(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final params = [
      if (cycle.programName != null) cycle.programName!,
      if (cycle.programTemperatureCelsius != null)
        '${cycle.programTemperatureCelsius} °C',
      if (cycle.programPlateauMinutes != null)
        '${cycle.programPlateauMinutes} min',
    ].join(' · ');
    final started = _startedAgo();

    return AppCard(
      onTap: onTap,
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
                      cycle.deviceName.toUpperCase(),
                      style: AppTypography.eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cycle #${cycle.number}',
                      style: AppTypography.cardTitle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _statusBadgeFor(cycle.status),
            ],
          ),
          if (params.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceWell,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.thermostat_outlined,
                    size: 16,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      params,
                      style: AppTypography.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (cycle.operatorName != null) ...[
                const Icon(
                  Icons.person_outline,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    cycle.operatorName!,
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              const Icon(
                Icons.schedule,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  started ??
                      (cycle.createdAt == null
                          ? 'Pas encore démarré'
                          : DateFormat('dd/MM/yyyy HH:mm')
                              .format(cycle.createdAt!)),
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ],
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
