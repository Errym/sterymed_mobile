import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/inputs/filter_chip_row.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/list_tile_skeleton.dart';
import '../../data/models/non_conformity_data.dart';
import '../../data/repositories/non_conformity_repository.dart';
import '../bloc/non_conformity_list_bloc.dart';
import '../widgets/nc_create_sheet.dart';
import '../widgets/nc_resolve_dialog.dart';

class NonConformitiesScreen extends StatelessWidget {
  const NonConformitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NonConformityListBloc(getIt<NonConformityRepository>())
        ..add(const LoadNonConformities()),
      child: const _NcView(),
    );
  }
}

class _NcView extends StatefulWidget {
  const _NcView();
  @override
  State<_NcView> createState() => _NcViewState();
}

class _NcViewState extends State<_NcView> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final canManage = getIt<SessionStore>().hasPermission(
      'non_conformities.manage',
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Non-Conformités & Rappels',
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'Nouvelle non-conformité',
              icon: const Icon(Icons.add),
              onPressed: () async {
                final ok = await NcCreateSheet.show(context);
                if (ok == true && context.mounted) {
                  context
                      .read<NonConformityListBloc>()
                      .add(const LoadNonConformities());
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          FilterChipRow<String?>(
            selected: _statusFilter,
            onSelected: (v) {
              setState(() => _statusFilter = v);
              context
                  .read<NonConformityListBloc>()
                  .add(FilterNonConformities(v));
            },
            options: const [
              FilterChipOption(value: null, label: 'Toutes'),
              FilterChipOption(value: 'open', label: 'En cours'),
              FilterChipOption(value: 'resolved', label: 'Résolues'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: BlocBuilder<NonConformityListBloc, NonConformityListState>(
              builder: (context, state) {
                if (state.status == NonConformityStatus.loading &&
                    state.items.isEmpty) {
                  return const ListSkeleton();
                }
                if (state.status == NonConformityStatus.failure) {
                  return ErrorView(
                    message: state.error ?? 'Erreur',
                    onRetry: () => context
                        .read<NonConformityListBloc>()
                        .add(const LoadNonConformities()),
                  );
                }
                if (state.items.isEmpty) {
                  return EmptyView(
                    title: 'Aucune non-conformité',
                    message: _statusFilter == 'open'
                        ? 'Aucun incident en cours.'
                        : _statusFilter == 'resolved'
                            ? 'Aucune non-conformité résolue.'
                            : 'Aucun incident enregistré.',
                    icon: Icons.verified_outlined,
                    action: canManage
                        ? FilledButton.icon(
                            onPressed: () async {
                              final ok = await NcCreateSheet.show(context);
                              if (ok == true && context.mounted) {
                                context
                                    .read<NonConformityListBloc>()
                                    .add(const LoadNonConformities());
                              }
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Nouvelle non-conformité'),
                          )
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => context
                      .read<NonConformityListBloc>()
                      .add(const LoadNonConformities()),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    itemCount: state.items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (_, i) => AnimatedListItem(
                      index: i,
                      child: _NcCard(
                        item: state.items[i],
                        canManage: canManage,
                      ),
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

class _NcCard extends StatelessWidget {
  final NonConformityData item;
  final bool canManage;
  const _NcCard({required this.item, required this.canManage});

  /// "Ouverte depuis 3 jours", for an incident still waiting for a decision.
  String? get _age {
    if (!item.isOpen) return null;
    final d = DateTime.now().difference(item.raisedAt);
    if (d.inHours < 1) return 'Ouverte depuis moins d\'une heure';
    if (d.inHours < 24) return 'Ouverte depuis ${d.inHours} h';
    return 'Ouverte depuis ${d.inDays} jour${d.inDays > 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = item.isOpen ? AppColors.danger : AppColors.success;
    final age = _age;
    final isCycle = item.subjectType.toLowerCase().contains('cycle');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TypeBadge(
                            label: item.subjectTypeLabel,
                            tone: BadgeTone.blue,
                          ),
                          const Spacer(),
                          TypeBadge(
                            label: item.isOpen ? 'En cours' : 'Résolu',
                            tone: item.isOpen
                                ? BadgeTone.yellow
                                : BadgeTone.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(item.description, style: AppTypography.cardTitle),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Signalé le '
                        '${DateFormat('dd/MM/yyyy HH:mm').format(item.raisedAt)}'
                        '${item.raisedByName != null ? ' par ${item.raisedByName}' : ''}',
                        style: AppTypography.caption,
                      ),
                      if (age != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            age,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (isCycle || (item.isOpen && canManage)) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            if (isCycle)
                              TextButton.icon(
                                key: const Key('nc-open-cycle'),
                                onPressed: () => context.openRoute(
                                  Routes.cyclesDetail(item.subjectId),
                                ),
                                icon: const Icon(Icons.autorenew, size: 16),
                                label: const Text('Voir le cycle'),
                              ),
                            const Spacer(),
                            if (item.isOpen && canManage)
                              TextButton.icon(
                                onPressed: () async {
                                  final ok = await NcResolveDialog.show(
                                    context,
                                    ncId: item.id,
                                  );
                                  if (ok == true && context.mounted) {
                                    context
                                        .read<NonConformityListBloc>()
                                        .add(const LoadNonConformities());
                                  }
                                },
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Résoudre'),
                              ),
                          ],
                        ),
                      ],
                      if (item.resolution != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius:
                                BorderRadius.circular(AppRadius.control),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle,
                                  size: 16, color: AppColors.success),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  'Résolution : ${item.resolution}'
                                  '${item.resolvedByName != null ? ' (${item.resolvedByName})' : ''}'
                                  '${item.resolvedAt != null ? ' · ${DateFormat('dd/MM/yyyy').format(item.resolvedAt!)}' : ''}',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
