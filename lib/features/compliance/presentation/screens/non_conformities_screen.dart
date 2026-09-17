import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/non_conformity_data.dart';
import '../../data/repositories/non_conformity_repository.dart';
import '../bloc/non_conformity_list_bloc.dart';

class NonConformitiesScreen extends StatelessWidget {
  const NonConformitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NonConformityListBloc(getIt<NonConformityRepository>())
        ..add(const LoadNonConformities()),
      child: const _NonConformitiesView(),
    );
  }
}

class _NonConformitiesView extends StatelessWidget {
  const _NonConformitiesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Non-Conformités & Rappels',
        actions: [
          IconButton(
            icon: const Icon(Icons.notification_important_outlined,
                color: AppColors.danger),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<NonConformityListBloc, NonConformityListState>(
        builder: (context, state) {
          return Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    _Chip(
                      label: 'Toutes (${state.items.length})',
                      selected: state.statusFilter == null,
                      onTap: () => context
                          .read<NonConformityListBloc>()
                          .add(const FilterNonConformities(null)),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _Chip(
                      label: 'En cours',
                      selected: state.statusFilter == 'open',
                      onTap: () => context
                          .read<NonConformityListBloc>()
                          .add(const FilterNonConformities('open')),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _Chip(
                      label: 'Résolues',
                      selected: state.statusFilter == 'resolved',
                      onTap: () => context
                          .read<NonConformityListBloc>()
                          .add(const FilterNonConformities('resolved')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: _Body(state: state),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final NonConformityListState state;
  const _Body({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.status == NonConformityStatus.loading && state.items.isEmpty) {
      return const LoadingView();
    }
    if (state.status == NonConformityStatus.failure && state.items.isEmpty) {
      return ErrorView(message: state.error ?? 'Erreur');
    }
    if (state.items.isEmpty) {
      return const EmptyView(
        title: 'Aucune non-conformité',
        message: 'Aucun incident enregistré.',
        icon: Icons.verified_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) => _NcCard(item: state.items[i]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimary : AppColors.backgroundSubtle,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.brandPrimary : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodyStrong.copyWith(
            color: selected
                ? AppColors.textOnBrand
                : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _NcCard extends StatelessWidget {
  final NonConformityData item;
  const _NcCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final (typeTone, typeLabel) = switch (item.kind) {
      'recall' => (BadgeTone.red, 'RECALL'),
      'quarantine' => (BadgeTone.orange, 'QUARANTAINE'),
      _ => (BadgeTone.blue, 'CORRECTION'),
    };
    final statusTone = item.isOpen ? BadgeTone.yellow : BadgeTone.green;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: item.isOpen
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TypeBadge(label: typeLabel, tone: typeTone),
              const SizedBox(width: AppSpacing.sm),
              Text(item.reference, style: AppTypography.caption),
              const Spacer(),
              TypeBadge(
                label: item.isOpen ? 'En cours' : 'Résolu',
                tone: statusTone,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(item.title, style: AppTypography.bodyStrong),
          const SizedBox(height: AppSpacing.xs),
          Text(item.description, style: AppTypography.body),
          if (item.batchNumber != null || item.cycleNumber != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (item.cycleNumber != null)
                  _Tag(
                    icon: Icons.autorenew,
                    label: 'Cycle ${item.cycleNumber}',
                  ),
                if (item.batchNumber != null)
                  _Tag(
                    icon: Icons.inventory_2_outlined,
                    label: 'Lot ${item.batchNumber}',
                  ),
                if (item.sachetsAffected != null)
                  _Tag(
                    icon: Icons.numbers,
                    label: '${item.sachetsAffected} sachet(s)',
                  ),
              ],
            ),
          ],
          if (item.openedBy != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ouvert le ${item.openedAt.day.toString().padLeft(2, '0')}/${item.openedAt.month.toString().padLeft(2, '0')}/${item.openedAt.year} par ${item.openedBy}',
              style: AppTypography.caption,
            ),
          ],
          if (item.resolution != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Résolution : ${item.resolution}',
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
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Tag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}
