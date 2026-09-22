import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/inputs/filter_chip_row.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/cursor_paginated_list.dart';
import '../../data/models/audit_event_data.dart';
import '../../data/repositories/audit_repository.dart';
import '../bloc/audit_list_bloc.dart';

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
          IconButton(
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
              return FilterChipRow<String?>(
                selected: state.actionFilter,
                onSelected: (v) =>
                    context.read<AuditListBloc>().add(FilterAuditEvents(v)),
                options: const [
                  FilterChipOption(value: null, label: 'Tous'),
                  FilterChipOption(
                      value: 'auth.login_succeeded', label: 'Connexions'),
                  FilterChipOption(value: 'cycle.started', label: 'Cycles'),
                  FilterChipOption(
                      value: 'label_usage.recorded', label: 'Utilisations'),
                  FilterChipOption(value: 'product.created', label: 'Produits'),
                ],
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

class _AuditTile extends StatelessWidget {
  final AuditEventData event;
  const _AuditTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                child: Text(event.actionLabel, style: AppTypography.bodyStrong),
              ),
              Text(
                DateFormat('dd/MM/yy HH:mm').format(event.occurredAt),
                style: AppTypography.caption,
              ),
            ],
          ),
          if (event.actorLabel != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(event.actorLabel!, style: AppTypography.caption),
                ),
              ],
            ),
          ],
          if (event.subjectType != null) ...[
            const SizedBox(height: 2),
            Text(
              event.subjectType!,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
