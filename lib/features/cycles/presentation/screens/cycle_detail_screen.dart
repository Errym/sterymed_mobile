import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/models/control_test_data.dart';
import '../../data/models/cycle_attachment_data.dart';
import '../../data/models/cycle_data.dart';
import '../../data/models/cycle_item_data.dart';
import '../../data/models/cycle_release_data.dart';
import '../../data/repositories/cycle_repository.dart';
import '../bloc/cycle_detail_bloc.dart';
import '../bloc/cycle_transition_bloc.dart';
import '../widgets/cycle_detail_attachment_tile.dart';
import '../widgets/cycle_detail_control_test_row.dart';
import '../widgets/cycle_detail_item_row.dart';
import '../widgets/cycle_empty_hint.dart';
import '../widgets/cycle_info_banner.dart';
import '../widgets/cycle_info_card.dart';
import '../widgets/cycle_labels_section.dart';
import '../widgets/cycle_notes_section.dart';
import '../widgets/cycle_read_only_banner.dart';
import '../widgets/cycle_status_badge.dart';
import '../widgets/cycle_timeline.dart';
import '../widgets/item_editor_dialog.dart';
import '../widgets/release_decision_sheet.dart';

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

  /// Can instruments be added? Yes, as long as the cycle isn't released.
  bool _canAddInstruments(String status) =>
      status == 'created' ||
      status == 'in_progress' ||
      status == 'completed' ||
      status == 'awaiting_release';

  /// Can control tests be recorded? Backend requires cycle to be completed.
  bool _canAddControlTests(String status) =>
      status == 'completed' ||
      status == 'awaiting_release' ||
      status == 'released';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Détail du cycle'),
        backgroundColor: AppColors.backgroundApp,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: BlocListener<CycleTransitionBloc, CycleTransitionState>(
        listenWhen: (p, c) => p.status != c.status,
        listener: (context, state) {
          if (state.status == CycleTransitionStatus.success) {
            context.read<CycleDetailBloc>().add(RefreshCycleDetail(cycleId));
            final wasQueued =
                state.cycle?.isQueued == true || state.release?.isQueued == true;
            AppSnackbar.show(
              context,
              wasQueued
                  ? 'Enregistré localement. Synchronisation en attente.'
                  : 'Cycle mis à jour.',
              kind: wasQueued ? SnackKind.queued : SnackKind.success,
              actionLabel: wasQueued ? 'Voir la file' : null,
              onAction: wasQueued ? () => context.push(Routes.sync) : null,
            );
            Future.delayed(const Duration(milliseconds: 300), () {
              if (context.mounted) {
                context
                    .read<CycleTransitionBloc>()
                    .add(const ResetCycleTransition());
              }
            });
          }
          if (state.status == CycleTransitionStatus.failure) {
            AppSnackbar.show(
              context,
              state.error ?? 'Erreur',
              kind: SnackKind.error,
            );
            Future.delayed(const Duration(milliseconds: 300), () {
              if (context.mounted) {
                context
                    .read<CycleTransitionBloc>()
                    .add(const ResetCycleTransition());
              }
            });
          }
        },
        child: BlocBuilder<CycleDetailBloc, CycleDetailState>(
          builder: (context, state) {
            if (state.status == CycleDetailStatus.loading &&
                state.cycle == null) {
              return const LoadingView();
            }
            if (state.status == CycleDetailStatus.failure) {
              return ErrorView(
                message: state.error ?? 'Erreur',
                onRetry: () => context
                    .read<CycleDetailBloc>()
                    .add(LoadCycleDetail(cycleId)),
              );
            }
            final c = state.cycle;
            if (c == null) return const SizedBox.shrink();

            final session = getIt<SessionStore>();
            final canManage = session.hasPermission('cycles.manage');
            final canRelease = session.hasPermission('cycles.release');
            final canAddItems = _canAddInstruments(c.status) && canManage;
            final canAddTests = _canAddControlTests(c.status) && canManage;

            return RefreshIndicator(
              onRefresh: () async => context
                  .read<CycleDetailBloc>()
                  .add(RefreshCycleDetail(cycleId)),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // ── Header + info card ──
                  AnimatedListItem(
                    index: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Cycle ${c.number}',
                                  style: AppTypography.pageTitle),
                            ),
                            CycleStatusBadge(status: c.status),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CycleInfoCard(cycle: c),
                      ],
                    ),
                  ),

                  // ── Timeline ──
                  AnimatedListItem(
                    index: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.lg),
                        const SectionHeader(title: 'Chronologie'),
                        CycleTimeline(cycle: c),
                      ],
                    ),
                  ),

                  // ── Notes ──
                  AnimatedListItem(
                    index: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.lg),
                        const SectionHeader(title: 'Notes de suivi'),
                        CycleNotesSection(
                            cycleId: cycleId, initialNotes: c.notes),
                      ],
                    ),
                  ),

                  // ── Instruments ──
                  AnimatedListItem(
                    index: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.lg),
                        SectionHeader(
                          title: 'Instruments (${state.items.length})',
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: canAddItems
                                ? 'Ajouter un instrument'
                                : (canManage
                                    ? 'Cycle clôturé'
                                    : 'Réservé à la stérilisation'),
                            onPressed: canAddItems
                                ? () => _addItem(context, cycleId)
                                : null,
                          ),
                        ),
                        if (state.items.isEmpty)
                          const CycleEmptyHint('Aucun instrument enregistré.')
                        else
                          ...state.items.map((i) => CycleDetailItemRow(
                                item: i,
                                onEdit: canAddItems
                                    ? () => _editItem(context, cycleId, i)
                                    : null,
                                onDelete: canAddItems
                                    ? () => _deleteItem(context, cycleId, i)
                                    : null,
                              )),
                      ],
                    ),
                  ),

                  // ── Control tests ──
                  AnimatedListItem(
                    index: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.lg),
                        SectionHeader(
                          title: 'Contrôles (${state.controlTests.length})',
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: canAddTests
                                ? 'Enregistrer un contrôle'
                                : (canManage
                                    ? 'Disponible après la fin du cycle'
                                    : 'Réservé à la stérilisation'),
                            onPressed: canAddTests
                                ? () => _addControlTest(context, cycleId)
                                : null,
                          ),
                        ),
                        if (!canAddTests && state.controlTests.isEmpty) ...[
                          const CycleInfoBanner(
                            message:
                                'Les contrôles (Bowie-Dick, Helix, biologique) se '
                                'saisissent une fois le cycle terminé.',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        if (state.controlTests.isEmpty && canAddTests)
                          const CycleEmptyHint('Aucun contrôle enregistré.')
                        else ...[
                          if (state.controlTests.isNotEmpty) ...[
                            const CycleInfoBanner(
                              message:
                                  'Les contrôles ne peuvent pas être supprimés une '
                                  'fois enregistrés (exigence de traçabilité).',
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          ...state.controlTests
                              .map((t) => CycleDetailControlTestRow(test: t)),
                        ],
                      ],
                    ),
                  ),

                  // ── Attachments ──
                  AnimatedListItem(
                    index: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.lg),
                        SectionHeader(
                          title: 'Pièces jointes (${state.attachments.length})',
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: canManage
                                ? 'Ajouter une pièce jointe'
                                : 'Réservé à la stérilisation',
                            onPressed: canManage
                                ? () => context
                                    .go(Routes.cyclesAttachments(cycleId))
                                : null,
                          ),
                        ),
                        if (state.attachments.isEmpty)
                          const CycleEmptyHint('Aucune pièce jointe.')
                        else
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: state.attachments
                                .map((a) => CycleDetailAttachmentTile(
                                      a: a,
                                      onDelete: canManage
                                          ? () => _deleteAttachment(
                                              context, cycleId, a)
                                          : null,
                                    ))
                                .toList(),
                          ),
                      ],
                    ),
                  ),

                  // ── Release info ──
                  if (state.release != null)
                    AnimatedListItem(
                      index: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.lg),
                          const SectionHeader(title: 'Libération'),
                          _releaseCard(state.release!),
                        ],
                      ),
                    ),

                  // ── Labels ──
                  if (c.status == 'released' &&
                      session.hasPermission('labels.manage'))
                    AnimatedListItem(
                      index: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.lg),
                          const SectionHeader(title: 'Étiquettes'),
                          CycleLabelsSection(cycleId: cycleId),
                        ],
                      ),
                    ),

                  // ── Action button ──
                  AnimatedListItem(
                    index: 8,
                    child: Column(
                      children: [
                        const SizedBox(height: AppSpacing.xxl),
                        BlocBuilder<CycleTransitionBloc, CycleTransitionState>(
                          builder: (context, transitionState) {
                            final isLoading = transitionState.status ==
                                CycleTransitionStatus.loading;
                            return _actionButton(
                              context,
                              c,
                              isLoading,
                              canManage: canManage,
                              canRelease: canRelease,
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Action button
  // ─────────────────────────────────────────────────────────────────────────
  Widget _actionButton(
    BuildContext context,
    CycleData c,
    bool isLoading, {
    required bool canManage,
    required bool canRelease,
  }) {
    switch (c.status) {
      case 'created':
        if (!canManage) return const CycleReadOnlyBanner();
        return PrimaryButton(
          label: 'Démarrer le cycle',
          icon: Icons.play_arrow,
          isLoading: isLoading,
          onPressed: isLoading ? null : () => _confirmAndStart(context, c.id),
        );
      case 'in_progress':
        if (!canManage) return const CycleReadOnlyBanner();
        return PrimaryButton(
          label: 'Marquer comme terminé',
          icon: Icons.check,
          isLoading: isLoading,
          onPressed:
              isLoading ? null : () => _confirmAndComplete(context, c.id),
        );
      case 'completed':
        if (!canManage) return const CycleReadOnlyBanner();
        return PrimaryButton(
          label: 'Soumettre pour libération',
          icon: Icons.assignment_turned_in_outlined,
          isLoading: isLoading,
          onPressed: isLoading ? null : () => _confirmAndSubmit(context, c.id),
        );
      case 'awaiting_release':
        if (!canRelease) return const CycleReadOnlyBanner();
        return PrimaryButton(
          label: 'Prendre la décision de libération',
          icon: Icons.verified_outlined,
          isLoading: isLoading,
          onPressed: isLoading ? null : () => _release(context, c.id),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Transitions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _confirmAndStart(BuildContext context, String id) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Démarrer le cycle ?',
      message: 'Le cycle passera en cours de traitement.',
      confirmLabel: 'Démarrer',
    );
    if (ok && context.mounted) {
      context.read<CycleTransitionBloc>().add(StartCycle(id));
    }
  }

  Future<void> _confirmAndComplete(BuildContext context, String id) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Terminer le cycle ?',
      message: 'Vous pourrez ensuite soumettre pour libération.',
      confirmLabel: 'Terminer',
    );
    if (ok && context.mounted) {
      context.read<CycleTransitionBloc>().add(CompleteCycle(id));
    }
  }

  Future<void> _confirmAndSubmit(BuildContext context, String id) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Soumettre pour libération ?',
      message: 'Un responsable devra valider la conformité du cycle.',
      confirmLabel: 'Soumettre',
    );
    if (ok && context.mounted) {
      context.read<CycleTransitionBloc>().add(SubmitCycleForRelease(id));
    }
  }

  Future<void> _release(BuildContext context, String id) async {
    final result = await ReleaseDecisionSheet.show(context);
    if (result == null || !context.mounted) return;

    context.read<CycleTransitionBloc>().add(
          ReleaseCycle(
            cycleId: id,
            decision: result.decision,
            reason: result.reason,
          ),
        );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Items
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _addItem(BuildContext context, String cycleId) async {
    final result = await ItemEditorDialog.show(context);
    if (result == null || !context.mounted) return;

    try {
      await getIt<CycleRepository>().addItem(cycleId, {
        'description': result.description,
      });
      if (!context.mounted) return;
      AppSnackbar.show(context, 'Instrument ajouté.', kind: SnackKind.success);
      context.read<CycleDetailBloc>().add(RefreshCycleDetail(cycleId));
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  Future<void> _editItem(
    BuildContext context,
    String cycleId,
    CycleItemData item,
  ) async {
    final result = await ItemEditorDialog.show(
      context,
      initialDescription: item.description,
    );
    if (result == null || !context.mounted) return;

    try {
      await getIt<CycleRepository>().deleteItem(cycleId, item.id);
      await getIt<CycleRepository>().addItem(cycleId, {
        'description': result.description,
      });
      if (!context.mounted) return;
      AppSnackbar.show(context, 'Instrument modifié.', kind: SnackKind.success);
      context.read<CycleDetailBloc>().add(RefreshCycleDetail(cycleId));
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  Future<void> _deleteItem(
    BuildContext context,
    String cycleId,
    CycleItemData item,
  ) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Supprimer cet instrument ?',
      message: item.description,
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await getIt<CycleRepository>().deleteItem(cycleId, item.id);
      if (!context.mounted) return;
      AppSnackbar.show(context, 'Instrument supprimé.',
          kind: SnackKind.success);
      context.read<CycleDetailBloc>().add(RefreshCycleDetail(cycleId));
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Attachments
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _deleteAttachment(
    BuildContext context,
    String cycleId,
    CycleAttachmentData a,
  ) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Supprimer cette pièce jointe ?',
      message: a.fileName ?? 'Pièce jointe',
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await getIt<CycleRepository>().deleteAttachment(cycleId, a.id);
      if (!context.mounted) return;
      AppSnackbar.show(context, 'Pièce jointe supprimée.',
          kind: SnackKind.success);
      context.read<CycleDetailBloc>().add(RefreshCycleDetail(cycleId));
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Control tests
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _addControlTest(BuildContext context, String cycleId) async {
    ControlTestType type = ControlTestType.vacuum;
    ControlTestResult result = ControlTestResult.pass;
    final notesCtrl = TextEditingController();

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Enregistrer un contrôle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<ControlTestType>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: ControlTestType.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.label),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => type = v ?? type),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ControlTestResult>(
                    initialValue: result,
                    decoration: const InputDecoration(labelText: 'Résultat'),
                    items: ControlTestResult.values
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.label),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => result = v ?? result),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      );

      if (ok != true || !context.mounted) return;
      try {
        await getIt<CycleRepository>().addControlTest(cycleId, {
          'type': _typeToString(type),
          'result': result == ControlTestResult.pass ? 'pass' : 'fail',
          'performed_at': DateTime.now().toIso8601String(),
          if (notesCtrl.text.trim().isNotEmpty) 'notes': notesCtrl.text.trim(),
        });
        if (!context.mounted) return;
        AppSnackbar.show(context, 'Contrôle enregistré.',
            kind: SnackKind.success);
        context.read<CycleDetailBloc>().add(RefreshCycleDetail(cycleId));
      } catch (e) {
        if (!context.mounted) return;
        AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
      }
    } finally {
      notesCtrl.dispose();
    }
  }

  String _typeToString(ControlTestType t) {
    switch (t) {
      case ControlTestType.vacuum:
        return 'vacuum';
      case ControlTestType.bowieDick:
        return 'bowie_dick';
      case ControlTestType.helix:
        return 'helix';
      case ControlTestType.biological:
        return 'biological';
    }
  }

  Widget _releaseCard(CycleReleaseData release) {
    final isCompliant = release.decision == CycleReleaseDecision.compliant;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isCompliant ? AppColors.successLight : AppColors.dangerLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCompliant ? Icons.verified : Icons.cancel,
                color: isCompliant ? AppColors.success : AppColors.danger,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                isCompliant ? 'Cycle conforme' : 'Cycle rejeté',
                style: AppTypography.bodyStrong.copyWith(
                  color: isCompliant ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
          if (release.reason != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(release.reason!, style: AppTypography.caption),
          ],
          if (release.releasedByName != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Par ${release.releasedByName}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
