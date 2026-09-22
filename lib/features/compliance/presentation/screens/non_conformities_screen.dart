import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
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

class _NcView extends StatelessWidget {
  const _NcView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Non-Conformités & Rappels',
        actions: [
          IconButton(
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
      body: BlocBuilder<NonConformityListBloc, NonConformityListState>(
        builder: (context, state) {
          if (state.status == NonConformityStatus.loading &&
              state.items.isEmpty) {
            return const LoadingView();
          }
          if (state.status == NonConformityStatus.failure) {
            return ErrorView(message: state.error ?? 'Erreur');
          }
          if (state.items.isEmpty) {
            return EmptyView(
              title: 'Aucune non-conformité',
              message: 'Aucun incident enregistré.',
              icon: Icons.verified_outlined,
              action: FilledButton.icon(
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
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, i) => AnimatedListItem(
              index: i,
              child: _NcCard(item: state.items[i]),
            ),
          );
        },
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
          if (item.isOpen) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final ok = await NcResolveDialog.show(context, ncId: item.id);
                  if (ok == true && context.mounted) {
                    context
                        .read<NonConformityListBloc>()
                        .add(const LoadNonConformities());
                  }
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Résoudre'),
              ),
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
