import 'package:steriymed_mobile/core/utils/dispose_later.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/cards/kpi_card.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/cursor_paginated_list.dart';
import '../../data/models/prosthetic_case_data.dart';
import '../../data/models/prosthetic_summary_data.dart';
import '../../data/repositories/prosthetic_repository.dart';
import '../utils/prosthetic_scopes.dart';
import '../widgets/prosthetic_case_tile.dart';

/// Brief page 9: "the priority screen specifically requested."
///
/// Everything that decides WHO is on this screen is the server's job:
/// inclusion (returned from the lab, not placed, not cancelled), the days
/// elapsed (measured against the server date) and the 0-7 / 8-14 / 15+ day
/// buckets, which are counted over the whole waiting set — not over the page
/// that happens to be loaded — and applied as a server filter when tapped.
class ProstheticWaitingPlacementScreen extends StatefulWidget {
  const ProstheticWaitingPlacementScreen({super.key});

  @override
  State<ProstheticWaitingPlacementScreen> createState() =>
      _ProstheticWaitingPlacementScreenState();
}

class _ProstheticWaitingPlacementScreenState
    extends State<ProstheticWaitingPlacementScreen> {
  List<ProstheticCaseData> _items = [];
  String? _nextCursor;
  ProstheticSummaryData? _summary;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  /// null (all) | 'fresh' (0-7) | 'medium' (8-14) | 'urgent' (15+). Sent to
  /// the server, which filters the whole set.
  String? _aging;

  /// Same idea as the list bloc: a late answer for a previous bucket never
  /// overwrites the list the user is looking at now.
  int _generation = 0;

  bool get _canManage =>
      getIt<SessionStore>().hasPermission('prosthetic_cases.manage');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final aging = _aging;
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = getIt<ProstheticRepository>();
    try {
      final pageFuture = repo.waitingForPlacement(aging: aging);
      final summaryFuture = _loadSummary(repo);
      final page = await pageFuture;
      final summary = await summaryFuture;
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _summary = summary ?? _summary;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<ProstheticSummaryData?> _loadSummary(ProstheticRepository repo) async {
    try {
      return await repo.summary(scope: ProstheticScope.waitingForPlacement);
    } on ApiException {
      return null;
    }
  }

  Future<void> _loadMore() async {
    if (_nextCursor == null || _loadingMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await getIt<ProstheticRepository>()
          .waitingForPlacement(cursor: _nextCursor, aging: _aging);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = [..._items, ...page.items];
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } on ApiException catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _loadingMore = false);
    }
  }

  void _toggleAging(String value) {
    setState(() => _aging = _aging == value ? null : value);
    _load();
  }

  String _agingLabel(String value) {
    switch (value) {
      case 'fresh':
        return '0-7 jours';
      case 'medium':
        return '8-14 jours';
      default:
        return '15+ jours';
    }
  }

  Future<void> _open(ProstheticCaseData c) async {
    await context.push(Routes.prostheticDetail(c.id));
    if (mounted) await _load();
  }

  // ── Quick actions (one tap from the list, no need to open the case) ──

  Future<void> _schedule(ProstheticCaseData c) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: c.plannedPlacementDate ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Date de pose prévue',
    );
    if (picked == null || !mounted) return;
    final wire = DateFormat('yyyy-MM-dd').format(picked);
    try {
      final repo = getIt<ProstheticRepository>();
      if (c.status == ProstheticCaseStatus.receivedAtPractice) {
        await repo.changeStatus(
          c.id,
          status: ProstheticCaseStatus.placementScheduled.wire,
          plannedPlacementDate: wire,
        );
      } else {
        await repo.update(c.id, {'planned_placement_date': wire});
      }
      if (!mounted) return;
      AppSnackbar.show(context, 'Pose programmée.', kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  Future<void> _addNote(ProstheticCaseData c) async {
    final ctrl = TextEditingController();
    try {
      final text = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ajouter une note'),
          content: AppTextArea(
            label: 'Note',
            controller: ctrl,
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(ctrl.text.trim()),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      );
      if (text == null || text.isEmpty || !mounted) return;
      final stamp = DateFormat('dd/MM/yyyy').format(DateTime.now());
      final existing = (c.notes ?? '').trim();
      final merged = existing.isEmpty ? '$stamp : $text' : '$existing\n$stamp : $text';
      if (merged.length > 4000) {
        AppSnackbar.show(
          context,
          'Les remarques de ce dossier sont pleines (4000 caractères).',
          kind: SnackKind.error,
        );
        return;
      }
      await getIt<ProstheticRepository>().update(c.id, {'notes': merged});
      if (!mounted) return;
      AppSnackbar.show(context, 'Note ajoutée.', kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      disposeControllerLater(ctrl);
    }
  }

  Widget _row(ProstheticCaseData item, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AnimatedListItem(
        index: index,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProstheticCaseTile(item: item, onTap: () => _open(item)),
            // Hidden, not disabled, for people who cannot act on a case.
            if (_canManage)
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  TextButton.icon(
                    key: Key('waiting-schedule-${item.id}'),
                    onPressed: () => _schedule(item),
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      item.plannedPlacementDate == null
                          ? 'Programmer'
                          : 'Reprogrammer',
                    ),
                  ),
                  TextButton.icon(
                    key: Key('waiting-note-${item.id}'),
                    onPressed: () => _addNote(item),
                    icon: const Icon(Icons.edit_note_outlined, size: 18),
                    label: const Text('Note'),
                  ),
                  TextButton.icon(
                    key: Key('waiting-open-${item.id}'),
                    onPressed: () => _open(item),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Ouvrir'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final showSummary = _error == null && summary != null && summary.total > 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'En attente de pose'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSummary) ...[
            // ── Summary bar: 3 tappable bucket cards, counted by the server ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 104,
                      child: KpiCard(
                        label: '0-7 jours',
                        value: '${summary.fresh}',
                        icon: Icons.access_time,
                        accentColor: AppColors.agingFresh,
                        onTap: () => _toggleAging('fresh'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SizedBox(
                      height: 104,
                      child: KpiCard(
                        label: '8-14 jours',
                        value: '${summary.medium}',
                        icon: Icons.warning_amber_outlined,
                        accentColor: AppColors.agingMedium,
                        onTap: () => _toggleAging('medium'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SizedBox(
                      height: 104,
                      child: KpiCard(
                        label: '15+ jours',
                        value: '${summary.urgent}',
                        icon: Icons.error_outline,
                        accentColor: AppColors.agingUrgent,
                        onTap: () => _toggleAging('urgent'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _aging == null
                          ? '${summary.total} dossier${summary.total > 1 ? 's' : ''} en attente'
                          : 'Filtré : ${_agingLabel(_aging!)}',
                      key: const Key('waiting-total'),
                      style: AppTypography.caption,
                    ),
                  ),
                  if (_aging != null)
                    GestureDetector(
                      onTap: () => _toggleAging(_aging!),
                      child: Text(
                        'Effacer',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: CursorPaginatedList<ProstheticCaseData>(
              items: _items,
              isLoading: _loading,
              isLoadingMore: _loadingMore,
              hasMore: _nextCursor != null,
              error: _error,
              onRetry: _load,
              onRefresh: _load,
              onLoadMore: _loadMore,
              emptyTitle: _aging == null
                  ? 'Aucun dossier en attente'
                  : 'Aucun dossier dans cette tranche',
              emptyMessage: _aging == null
                  ? 'Aucun travail revenu du laboratoire n\'attend de pose.'
                  : 'Essayez une autre tranche d\'ancienneté.',
              emptyIcon: Icons.hourglass_empty,
              itemBuilder: (context, item, index) => _row(item, index),
            ),
          ),
        ],
      ),
    );
  }
}
