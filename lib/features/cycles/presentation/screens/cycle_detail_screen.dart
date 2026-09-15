import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../bloc/cycle_detail_bloc.dart';
import '../bloc/cycle_transition_bloc.dart';
import '../widgets/control_test_row.dart';
import '../widgets/cycle_attachment_grid.dart';
import '../widgets/cycle_item_row.dart';
import '../widgets/cycle_status_badge.dart';
import '../widgets/cycle_timeline.dart';
import '../widgets/transition_confirm_dialog.dart';

class CycleDetailScreen extends StatelessWidget {
  final String cycleId;
  const CycleDetailScreen({super.key, required this.cycleId});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (ctx) =>
              CycleDetailBloc(ctx.read())..add(LoadCycleDetail(cycleId)),
        ),
        BlocProvider(create: (ctx) => CycleTransitionBloc(ctx.read())),
      ],
      child: _CycleDetailView(cycleId: cycleId),
    );
  }
}

class _CycleDetailView extends StatelessWidget {
  final String cycleId;
  const _CycleDetailView({required this.cycleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Détail du cycle')),
      body: BlocListener<CycleTransitionBloc, CycleTransitionState>(
        listenWhen: (p, c) => p.status != c.status,
        listener: (context, state) {
          if (state.status == CycleTransitionStatus.success) {
            context.read<CycleDetailBloc>().add(RefreshCycleDetail(cycleId));
          }
          if (state.status == CycleTransitionStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error ?? 'Erreur')),
            );
          }
        },
        child: BlocBuilder<CycleDetailBloc, CycleDetailState>(
          builder: (context, state) {
            if (state.status == CycleDetailStatus.loading &&
                state.cycle == null) {
              return const LoadingView();
            }
            if (state.status == CycleDetailStatus.failure) {
              return ErrorView(message: state.error ?? 'Erreur');
            }
            final c = state.cycle;
            if (c == null) return const SizedBox.shrink();

            return RefreshIndicator(
              onRefresh: () async {
                context
                    .read<CycleDetailBloc>()
                    .add(RefreshCycleDetail(cycleId));
              },
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Cycle ${c.number}',
                          style: AppTypography.pageTitle,
                        ),
                      ),
                      CycleStatusBadge(status: c.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _infoCard(c),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(title: 'Chronologie'),
                  CycleTimeline(cycle: c),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: 'Instruments (${state.items.length})',
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => context.go(Routes.cyclesItems(c.id)),
                    ),
                  ),
                  if (state.items.isEmpty)
                    Text('Aucun instrument enregistré.',
                        style: AppTypography.caption)
                  else
                    ...state.items.map((i) => CycleItemRow(item: i)),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: 'Contrôles (${state.controlTests.length})',
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () =>
                          context.go(Routes.cyclesControlTests(c.id)),
                    ),
                  ),
                  if (state.controlTests.isEmpty)
                    Text('Aucun contrôle enregistré.',
                        style: AppTypography.caption)
                  else
                    ...state.controlTests.map((t) => ControlTestRow(test: t)),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: 'Pièces jointes (${state.attachments.length})',
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () =>
                          context.go(Routes.cyclesAttachments(c.id)),
                    ),
                  ),
                  CycleAttachmentGrid(attachments: state.attachments),
                  const SizedBox(height: AppSpacing.xxl),
                  _actionButton(context, c.id, c.status),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoCard(dynamic c) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          _row(Icons.precision_manufacturing_outlined, 'Appareil',
              c.deviceName as String),
          if (c.programName != null)
            _row(Icons.settings_suggest_outlined, 'Programme',
                c.programName as String),
          if (c.operatorName != null)
            _row(Icons.person_outline, 'Opérateur', c.operatorName as String),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: AppTypography.label),
          const Spacer(),
          Text(value, style: AppTypography.bodyStrong),
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context, String cycleId, String status) {
    switch (status) {
      case 'created':
        return PrimaryButton(
          label: 'Démarrer le cycle',
          icon: Icons.play_arrow,
          onPressed: () async {
            final ok = await TransitionConfirmDialog.show(
              context,
              title: 'Démarrer le cycle ?',
              message: 'Le cycle passera en cours de traitement.',
            );
            if (ok && context.mounted) {
              context.read<CycleTransitionBloc>().add(StartCycle(cycleId));
            }
          },
        );
      case 'in_progress':
        return PrimaryButton(
          label: 'Marquer comme terminé',
          icon: Icons.check,
          onPressed: () async {
            final ok = await TransitionConfirmDialog.show(
              context,
              title: 'Terminer le cycle ?',
              message: 'Vous pourrez ensuite soumettre pour libération.',
            );
            if (ok && context.mounted) {
              context.read<CycleTransitionBloc>().add(CompleteCycle(cycleId));
            }
          },
        );
      case 'completed':
        return PrimaryButton(
          label: 'Soumettre pour libération',
          icon: Icons.assignment_turned_in_outlined,
          onPressed: () async {
            final ok = await TransitionConfirmDialog.show(
              context,
              title: 'Soumettre pour libération ?',
              message: 'Un responsable devra valider la conformité.',
            );
            if (ok && context.mounted) {
              context
                  .read<CycleTransitionBloc>()
                  .add(SubmitCycleForRelease(cycleId));
            }
          },
        );
      case 'awaiting_release':
        return PrimaryButton(
          label: 'Prendre la décision de libération',
          icon: Icons.verified_outlined,
          onPressed: () => context.go(Routes.cyclesRelease(cycleId)),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
