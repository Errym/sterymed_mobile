import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/inputs/filter_chip_row.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/cursor_paginated_list.dart';
import '../../data/models/audit_event_data.dart';
import '../../data/repositories/audit_repository.dart';
import '../bloc/audit_list_bloc.dart';
import '../widgets/audit_filter_sheet.dart';

class AuditListScreen extends StatelessWidget {
  const AuditListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          AuditListBloc(getIt<AuditRepository>())..add(const LoadAuditEvents()),
      child: const _AuditListView(),
    );
  }
}

class _AuditListView extends StatelessWidget {
  const _AuditListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Journal d\'Audit',
        actions: [
          BlocBuilder<AuditListBloc, AuditListState>(
            builder: (context, state) {
              return IconButton(
                icon: Icon(
                  state.hasAdvancedFilters
                      ? Icons.filter_alt
                      : Icons.filter_alt_outlined,
                  color: state.hasAdvancedFilters
                      ? AppColors.brandPrimary
                      : null,
                ),
                tooltip: 'Filtres avancés',
                onPressed: () async {
                  final bloc = context.read<AuditListBloc>();
                  final result = await AuditFilterSheet.show(
                    context,
                    knownActors: state.knownActors,
                    knownSubjectTypes: state.knownSubjectTypes,
                    actorId: state.actorIdFilter,
                    subjectType: state.subjectTypeFilter,
                    from: state.fromFilter,
                    to: state.toFilter,
                  );
                  if (result != null) {
                    bloc.add(ApplyAdvancedAuditFilters(
                      actorId: result.actorId,
                      actorLabel: result.actorLabel,
                      subjectType: result.subjectType,
                      from: result.from,
                      to: result.to,
                    ));
                  }
                },
              );
            },
          ),
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<AuditListBloc>().add(const RefreshAuditEvents()),
          ),
        ],
      ),
      body: Column(
        children: [
          BlocBuilder<AuditListBloc, AuditListState>(
            builder: (context, state) {
              const quick = <FilterChipOption<String?>>[
                FilterChipOption(value: null, label: 'Tous'),
                FilterChipOption(
                    value: 'auth.login_succeeded', label: 'Connexions'),
                FilterChipOption(value: 'cycle.started', label: 'Cycles'),
                FilterChipOption(
                    value: 'label_usage.recorded', label: 'Utilisations'),
                FilterChipOption(value: 'product.created', label: 'Produits'),
              ];
              final current = state.actionFilter;
              final isQuick = quick.any((o) => o.value == current);
              return FilterChipRow<String?>(
                selected: current,
                onSelected: (v) async {
                  final bloc = context.read<AuditListBloc>();
                  if (v == _moreActions) {
                    final picked = await _pickAction(context, current);
                    if (picked != null) {
                      bloc.add(FilterAuditEvents(
                          picked == _allActions ? null : picked));
                    }
                    return;
                  }
                  bloc.add(FilterAuditEvents(v));
                },
                options: [
                  quick.first,
                  // Second, so it is seen without scrolling the row.
                  const FilterChipOption(
                      value: _moreActions, label: 'Autres actions…'),
                  // An action chosen from the full list stays visible and
                  // selected, instead of leaving every chip unselected.
                  if (current != null && !isQuick)
                    FilterChipOption(
                      value: current,
                      label: AuditEventData.actionLabels[current] ?? current,
                    ),
                  ...quick.skip(1),
                ],
              );
            },
          ),
          BlocBuilder<AuditListBloc, AuditListState>(
            builder: (context, state) {
              if (!state.hasAdvancedFilters) return const SizedBox.shrink();
              final parts = <String>[
                if (state.actorLabelFilter != null) state.actorLabelFilter!,
                if (state.subjectTypeFilter != null)
                  (state.knownSubjectTypes
                          .where((e) => e.key == state.subjectTypeFilter)
                          .firstOrNull
                          ?.value ??
                      state.subjectTypeFilter!),
                if (state.fromFilter != null || state.toFilter != null)
                  '${state.fromFilter != null ? _fmtDate(state.fromFilter!) : '…'}'
                  ' → '
                  '${state.toFilter != null ? _fmtDate(state.toFilter!) : '…'}',
              ];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        parts.join(' · '),
                        style: AppTypography.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context
                          .read<AuditListBloc>()
                          .add(const ApplyAdvancedAuditFilters()),
                      child: Text(
                        'Effacer',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: BlocBuilder<AuditListBloc, AuditListState>(
              builder: (context, state) {
                return CursorPaginatedList<AuditEventData>(
                  items: state.events,
                  isLoading: state.status == AuditStatus.loading,
                  isLoadingMore: state.isLoadingMore,
                  hasMore: state.hasMore,
                  error: state.status == AuditStatus.failure
                      ? (state.error ?? 'Erreur')
                      : null,
                  onRetry: () =>
                      context.read<AuditListBloc>().add(const LoadAuditEvents()),
                  onLoadMore: () async => context
                      .read<AuditListBloc>()
                      .add(const LoadMoreAuditEvents()),
                  onRefresh: () async => context
                      .read<AuditListBloc>()
                      .add(const RefreshAuditEvents()),
                  emptyTitle: 'Aucun événement',
                  emptyMessage: 'Aucune action enregistrée pour ce filtre.',
                  emptyIcon: Icons.history_toggle_off,
                  itemBuilder: (_, event, i) => AnimatedListItem(
                    index: i,
                    child: _AuditTile(event: event),
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

const _moreActions = '__more_actions__';
const _allActions = '__all_actions__';

/// Every action the server records, searchable, in French.
Future<String?> _pickAction(BuildContext context, String? current) {
  final entries = AuditEventData.actionLabels.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.backgroundApp,
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: ListView(
          key: const Key('audit-action-list'),
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('Filtrer par action', style: AppTypography.sectionTitle),
            ),
            ListTile(
              title: const Text('Toutes les actions'),
              selected: current == null,
              onTap: () => Navigator.of(ctx).pop(_allActions),
            ),
            for (final e in entries)
              ListTile(
                key: Key('audit-action-${e.key}'),
                title: Text(e.value),
                selected: current == e.key,
                onTap: () => Navigator.of(ctx).pop(e.key),
              ),
          ],
        ),
      ),
    ),
  );
}

String _fmtDate(DateTime d) => DateFormat('dd/MM/yy').format(d);

class _AuditTile extends StatefulWidget {
  final AuditEventData event;
  const _AuditTile({required this.event});

  @override
  State<_AuditTile> createState() => _AuditTileState();
}

class _AuditTileState extends State<_AuditTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final changes = e.changes;
    final actor = e.actorLabel ?? '';
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EntityMark.initials(
                actor.isEmpty ? '•' : EntityMark.initialsOf(actor),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy · HH:mm').format(e.occurredAt),
                      style: AppTypography.eyebrow,
                    ),
                    const SizedBox(height: 2),
                    Text(e.actionLabel, style: AppTypography.cardTitle),
                    if (actor.isNotEmpty)
                      Text(actor, style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
          if (e.subjectTypeLabel != null || (e.reason ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (e.subjectTypeLabel != null)
                  InfoTag(e.subjectTypeLabel!, icon: Icons.label_outline),
              ],
            ),
          ],
          if ((e.reason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Motif : ${e.reason!.trim()}', style: AppTypography.caption),
          ],
          if (changes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            InkWell(
              key: const Key('audit-toggle-changes'),
              onTap: () => setState(() => _open = !_open),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _open
                          ? 'Masquer les changements'
                          : 'Voir les changements (${changes.length})',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: AppColors.brandPrimary,
                    ),
                  ],
                ),
              ),
            ),
            if (_open)
              Container(
                key: const Key('audit-changes'),
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWell,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in changes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.field, style: AppTypography.eyebrow),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    c.before,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.danger,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(Icons.arrow_forward,
                                      size: 12,
                                      color: AppColors.textSecondary),
                                ),
                                Flexible(
                                  child: Text(
                                    c.after,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
