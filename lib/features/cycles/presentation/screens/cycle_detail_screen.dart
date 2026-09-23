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
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/local/cycle_notes_cache.dart';
import '../../data/models/control_test_data.dart';
import '../../data/models/cycle_attachment_data.dart';
import '../../data/models/cycle_data.dart';
import '../../data/models/cycle_item_data.dart';
import '../../data/models/cycle_release_data.dart';
import '../../data/repositories/cycle_repository.dart';
import '../bloc/cycle_detail_bloc.dart';
import '../bloc/cycle_transition_bloc.dart';
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
            AppSnackbar.show(context, 'Cycle mis à jour.',
                kind: SnackKind.success);
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
                        _infoCard(c),
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
                        _NotesSection(cycleId: cycleId, initialNotes: c.notes),
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
                          const _EmptyHint('Aucun instrument enregistré.')
                        else
                          ...state.items.map((i) => _ItemRow(
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
                          const _InfoBanner(
                            message:
                                'Les contrôles (Bowie-Dick, Helix, biologique) se '
                                'saisissent une fois le cycle terminé.',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        if (state.controlTests.isEmpty && canAddTests)
                          const _EmptyHint('Aucun contrôle enregistré.')
                        else ...[
                          if (state.controlTests.isNotEmpty) ...[
                            const _InfoBanner(
                              message:
                                  'Les contrôles ne peuvent pas être supprimés une '
                                  'fois enregistrés (exigence de traçabilité).',
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          ...state.controlTests
                              .map((t) => _ControlTestRow(test: t)),
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
                          const _EmptyHint('Aucune pièce jointe.')
                        else
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: state.attachments
                                .map((a) => _AttachmentTile(
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

                  // ── Action button ──
                  AnimatedListItem(
                    index: 7,
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
          _row(Icons.precision_manufacturing_outlined, 'Appareil',
              c.deviceName.isEmpty ? 'Appareil inconnu' : c.deviceName),
          if (c.programName != null)
            _row(Icons.thermostat_outlined, 'Programme', c.programName!),
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
        if (!canManage) return const _ReadOnlyBanner();
        return PrimaryButton(
          label: 'Démarrer le cycle',
          icon: Icons.play_arrow,
          isLoading: isLoading,
          onPressed: isLoading ? null : () => _confirmAndStart(context, c.id),
        );
      case 'in_progress':
        if (!canManage) return const _ReadOnlyBanner();
        return PrimaryButton(
          label: 'Marquer comme terminé',
          icon: Icons.check,
          isLoading: isLoading,
          onPressed:
              isLoading ? null : () => _confirmAndComplete(context, c.id),
        );
      case 'completed':
        if (!canManage) return const _ReadOnlyBanner();
        return PrimaryButton(
          label: 'Soumettre pour libération',
          icon: Icons.assignment_turned_in_outlined,
          isLoading: isLoading,
          onPressed: isLoading ? null : () => _confirmAndSubmit(context, c.id),
        );
      case 'awaiting_release':
        if (!canRelease) return const _ReadOnlyBanner();
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

// ─────────────────────────────────────────────────────────────────────────────
// Notes section
// ─────────────────────────────────────────────────────────────────────────────

class _NotesSection extends StatefulWidget {
  final String cycleId;
  final String? initialNotes;

  const _NotesSection({required this.cycleId, this.initialNotes});

  @override
  State<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<_NotesSection> {
  final _cache = CycleNotesCache();
  final _notesCtrl = TextEditingController();
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cached = await _cache.get(widget.cycleId);
    if (!mounted) return;
    setState(() {
      _notesCtrl.text = cached ?? widget.initialNotes ?? '';
      _loading = false;
      _editing = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _cache.save(widget.cycleId, _notesCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = false;
    });
    AppSnackbar.show(context, 'Notes enregistrées.', kind: SnackKind.success);
  }

  void _cancel() {
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextArea(
            controller: _notesCtrl,
            hint:
                'Ex : Cassettes chirurgicales Dr. Watson, sachets turbines...',
            maxLines: 5,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _saving ? null : _cancel,
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: 'Enregistrer',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ],
      );
    }

    final hasNotes = _notesCtrl.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hasNotes ? _notesCtrl.text : 'Aucune note pour ce cycle.',
                  style: hasNotes ? AppTypography.body : AppTypography.caption,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.brandPrimary),
                tooltip: hasNotes ? 'Modifier' : 'Ajouter',
                onPressed: () => setState(() => _editing = true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Enregistrées localement — non synchronisées avec le serveur '
            '(pas d\'endpoint disponible).',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
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

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return const _InfoBanner(
      message: 'Vous consultez ce cycle en lecture seule. Contactez '
          'l\'équipe de stérilisation pour toute modification.',
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;
  const _InfoBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.info),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(color: AppColors.info),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final CycleItemData item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ItemRow({
    required this.item,
    this.onEdit,
    this.onDelete,
  });

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
                  Text('Lot ${item.batchNumber}', style: AppTypography.caption),
                ],
              ],
            ),
          ),
          if (onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  size: 20, color: AppColors.textSecondary),
              onSelected: (v) {
                if (v == 'edit') onEdit?.call();
                if (v == 'delete') onDelete?.call();
              },
              itemBuilder: (_) => [
                if (onEdit != null)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Modifier'),
                    ]),
                  ),
                if (onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 18, color: AppColors.danger),
                      SizedBox(width: 8),
                      Text('Supprimer',
                          style: TextStyle(color: AppColors.danger)),
                    ]),
                  ),
              ],
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
  final VoidCallback? onDelete;

  const _AttachmentTile({required this.a, this.onDelete});

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
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.image_outlined,
                color: AppColors.textSecondary, size: 24),
          ),
          if (onDelete != null)
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: AppColors.backgroundCard,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14, color: AppColors.danger),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
