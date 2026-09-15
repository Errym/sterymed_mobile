import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/lists/list_tile_skeleton.dart';
import '../bloc/cycle_list_bloc.dart';
import '../widgets/cycle_tile.dart';

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

  static const _tabs = <_Tab>[
    _Tab('Tous', null),
    _Tab('Créés', 'created'),
    _Tab('En cours', 'in_progress'),
    _Tab('Terminés', 'completed'),
    _Tab('Libérés', 'released'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Cycles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go(Routes.cyclesCreate),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: BlocBuilder<CycleListBloc, CycleListState>(
              builder: (context, state) {
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: _tabs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.xs),
                  itemBuilder: (_, i) {
                    final t = _tabs[i];
                    final selected = state.selectedStatus == t.status;
                    return ChoiceChip(
                      label: Text(t.label),
                      selected: selected,
                      onSelected: (_) => context
                          .read<CycleListBloc>()
                          .add(FilterCycles(t.status)),
                    );
                  },
                );
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<CycleListBloc, CycleListState>(
              builder: (context, state) {
                if (state.status == CycleListStatus.loading &&
                    state.cycles.isEmpty) {
                  return const ListSkeleton();
                }
                if (state.status == CycleListStatus.failure &&
                    state.cycles.isEmpty) {
                  return ErrorView(
                    message: state.error ?? 'Erreur',
                    onRetry: () =>
                        context.read<CycleListBloc>().add(const LoadCycles()),
                  );
                }
                final filtered = state.filtered;
                if (filtered.isEmpty) {
                  return const EmptyView(
                    title: 'Aucun cycle',
                    message: 'Créez un nouveau cycle de stérilisation.',
                    icon: Icons.autorenew,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      context.read<CycleListBloc>().add(const RefreshCycles()),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      return CycleTile(
                        cycle: c,
                        onTap: () => context.go(Routes.cyclesDetail(c.id)),
                      );
                    },
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

class _Tab {
  final String label;
  final String? status;
  const _Tab(this.label, this.status);
}
