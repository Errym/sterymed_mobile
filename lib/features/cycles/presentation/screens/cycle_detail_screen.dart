import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../data/models/control_test_data.dart';
import '../../data/models/cycle_attachment_data.dart';
import '../../data/models/cycle_data.dart';
import '../../data/models/cycle_item_data.dart';
import '../../data/repositories/cycle_repository.dart';
import '../bloc/cycle_detail_bloc.dart';
import '../bloc/cycle_transition_bloc.dart';
import '../widgets/cycle_status_badge.dart';
import '../widgets/cycle_timeline.dart';
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
            context
                .read<CycleDetailBloc>()
                .add(RefreshCycleDetail(cycleId));
            AppSnackbar.show(context, 'Cycle mis à jour.',
                kind: SnackKind.success);
          }
          if (state.status == CycleTransitionStatus.failure) {
            AppSnackbar.show(context, state.error ?? 'Erreur',
                kind: SnackKind.error);
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

            return RefreshIndicator(
              onRefresh: () async => context
                  .read<CycleDetailBloc>()
                  .add(RefreshCycleDetail(cycleId)),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // ── Header ──
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

                  // ── Info card ──
                  _infoCard(c),

                  // ── Timeline ──
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(title: 'Chronologie'),
                  CycleTimeline(cycle: c),

                  // ── Items ──
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: 'Instruments (${state.items.length})',
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Ajouter un instrument',
                      onPressed: () => _addItem(context, cycleId),
                    ),
                  ),
                  if (state.items.isEmpty)
                    const _EmptyHint('Aucun instrument enregistré.')
                  else
                    ...state.items.map((i) => _ItemRow(
                          item: i,
                          onDelete: () => _deleteItem(context, cycleId, i),
                        )),

                  // ── Control tests ──
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: 'Contrôles (${state.controlTests.length})',
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Enregistrer un contrôle',
                      onPressed: () => _addControlTest(context, cycleId),
                    ),
                  ),
                  if (state.controlTests.isEmpty)
                    const _EmptyHint('Aucun contrôle enregistré.')
                  else
                    ...state.controlTests.map((t) => _ControlTestRow(test: t)),

                  // ── Attachments ──
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: 'Pièces jointes (${state.attachments.length})',
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Ajouter une pièce jointe',
                      onPressed: () =>
                          context.go(Routes.cyclesAttachments(cycleId)),
                    ),
                  ),
                  if (state.attachments.isEmpty)
                    const _EmptyHint('Aucune pièce jointe.')
                  else
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: state.attachments
                          .map((a) => _AttachmentTile(a: a))
                          .toList(),
                    ),

                  // ── Release info ──
                  if (state.release != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const SectionHeader(title: 'Libération'),
                    _releaseCard(state.release!),
                  ],

                  // ── Action button ──
                  const SizedBox(height: AppSpacing.xxl),
                  _actionButton(context, c),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Info card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _infoCard(CycleData c) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          _row(Icons.precision_manufacturing_outlined, 'Appareil', c.deviceName),
          if (c.programName != null)
            _row(Icons.settings_suggest_outlined, 'Programme', c.programName!),
          if (c.operatorName != null)
            _row(Icons.person_outline, 'Opérateur', c.operatorName!),
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
          Flexible(
            child: Text(
              value,
              style: AppTypography.bodyStrong,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Action button — dispatches to the transition bloc
  // ─────────────────────────────────────────────────────────────────────────
  Widget _actionButton(BuildContext context, CycleData c) {
    switch (c.status) {
      case 'created':
        return PrimaryButton(
          label: 'Démarrer le cycle',
          icon: Icons.play_arrow,
          onPressed: () => _confirmAndStart(context, c.id),
        );
      case 'in_progress':
        return PrimaryButton(
          label: 'Marquer comme terminé',
          icon: Icons.check,
          onPressed: () => _confirmAndComplete(context, c.id),
        );
      case 'completed':
        return PrimaryButton(
          label: 'Soumettre pour libération',
          icon: Icons.assignment_turned_in_outlined,
          onPressed: () => _confirmAndSubmit(context, c.id),
        );
      case 'awaiting_release':
        return PrimaryButton(
          label: 'Prendre la décision de libération',
          icon: Icons.verified_outlined,
          onPressed: () => _release(context, c.id),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions
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

    try {
      final repo = getIt<CycleRepository>();
      final release = await repo.release(
        id,
        decision: result.decision,
        reason: result.reason,
      );
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        'Décision enregistrée : ${release.decision.name}',
        kind: SnackKind.success,
      );
      // Refresh the detail screen
      context.read<CycleDetailBloc>().add(RefreshCycleDetail(id));
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    }
  }

  Future<void> _addItem(BuildContext context, String cycleId) async {
    final descCtrl = TextEditingController();
    final batchCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Ajouter un instrument'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Ex : Cassette chirurgicale',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: batchCtrl,
              decoration: const InputDecoration(
                labelText: 'Lot (optionnel)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    try {
      await getIt<CycleRepository>().addItem(cycleId, {
        'description': descCtrl.text.trim(),
        if (batchCtrl.text.trim().isNotEmpty)
          'batch_id': batchCtrl.text.trim(),
      });
      if (!context.mounted) return;
      AppSnackbar.show(context, 'Instrument ajouté.', kind: SnackKind.success);
      context.read<CycleDetailBloc>().add(RefreshCycleDetail(cycleId));
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    }
  }

  Future<void> _deleteItem(
      BuildContext context, String cycleId, CycleItemData item) async {
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
      context.read<CycleDetailBloc>().add(RefreshCycleDetail(cycleId));
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    }
  }

  Future<void> _addControlTest(BuildContext context, String cycleId) async {
    ControlTestType type = ControlTestType.vacuum;
    ControlTestResult result = ControlTestResult.pass;
    final notesCtrl = TextEditingController();

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
      AppSnackbar.show(context, 'Contrôle enregistré.', kind: SnackKind.success);
      context.read<CycleDetailBloc>().add(RefreshCycleDetail(cycleId));
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
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

  Widget _releaseCard(dynamic release) {
    final isCompliant = release.decision.name == 'compliant';
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(text, style: AppTypography.caption),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final CycleItemData item;
  final VoidCallback onDelete;
  const _ItemRow({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description, style: AppTypography.bodyStrong),
                if (item.batchNumber != null) ...[
                  const SizedBox(height: 2),
                  Text('Lot ${item.batchNumber}',
                      style: AppTypography.caption),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.danger, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ControlTestRow extends StatelessWidget {
  final ControlTestData test;
  const _ControlTestRow({required this.test});

  @override
  Widget build(BuildContext context) {
    final isPass = test.result == ControlTestResult.pass;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(test.type.label, style: AppTypography.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  _formatDateTime(test.performedAt),
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isPass ? AppColors.successLight : AppColors.dangerLight,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              test.result.label,
              style: AppTypography.caption.copyWith(
                color: isPass ? AppColors.success : AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} · '
        '${two(d.hour)}:${two(d.minute)}';
  }
}

class _AttachmentTile extends StatelessWidget {
  final CycleAttachmentData a;
  const _AttachmentTile({required this.a});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.backgroundSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined,
            color: AppColors.textSecondary, size: 24),
      ),
    );
  }
}
