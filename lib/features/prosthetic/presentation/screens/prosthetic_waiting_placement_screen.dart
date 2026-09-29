import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/cursor_page.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/cards/kpi_card.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/cursor_paginated_list.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/prosthetic_case_data.dart';
import '../../data/repositories/prosthetic_repository.dart';
import '../widgets/prosthetic_case_tile.dart';

/// Brief page 9: "the priority screen specifically requested."
///
/// Aging is computed server-side (`daysWaitingForPlacement`) and rendered
/// per-row via [ProstheticCaseTile]'s `AgingBadge`. This screen adds a
/// summary bar (0-7 / 8-14 / 15+ day buckets) that doubles as a
/// client-side filter over the loaded page.
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
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  /// Local-only aging filter: null (all) | 'fresh' (0-7) | 'medium' (8-14)
  /// | 'urgent' (15+). Purely client-side over the already-loaded page;
  /// the backend query is unchanged.
  String? _agingFilter;

  int get _freshCount =>
      _items.where((c) => (c.daysWaitingForPlacement ?? 0) <= 7).length;

  int get _mediumCount => _items.where((c) {
        final d = c.daysWaitingForPlacement ?? 0;
        return d >= 8 && d <= 14;
      }).length;

  int get _urgentCount =>
      _items.where((c) => (c.daysWaitingForPlacement ?? 0) >= 15).length;

  List<ProstheticCaseData> get _visibleItems {
    if (_agingFilter == null) return _items;
    return _items.where((c) {
      final d = c.daysWaitingForPlacement ?? 0;
      if (_agingFilter == 'fresh') return d <= 7;
      if (_agingFilter == 'medium') return d >= 8 && d <= 14;
      return d >= 15;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final CursorPage<ProstheticCaseData> page =
          await getIt<ProstheticRepository>().waitingForPlacement();
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_nextCursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await getIt<ProstheticRepository>()
          .waitingForPlacement(cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page.items];
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } on ApiException catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _toggleFilter(String value) {
    setState(() {
      _agingFilter = _agingFilter == value ? null : value;
    });
  }

  String _filterLabel(String value) {
    switch (value) {
      case 'fresh':
        return '0-7 jours';
      case 'medium':
        return '8-14 jours';
      default:
        return '15+ jours';
    }
  }

  @override
  Widget build(BuildContext context) {
    final showSummary = !_loading && _error == null && _items.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'En attente de pose'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSummary) ...[
            // ── Summary bar: 3 tappable bucket cards ──
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
                        value: '$_freshCount',
                        icon: Icons.access_time,
                        accentColor: AppColors.agingFresh,
                        onTap: () => _toggleFilter('fresh'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SizedBox(
                      height: 104,
                      child: KpiCard(
                        label: '8-14 jours',
                        value: '$_mediumCount',
                        icon: Icons.warning_amber_outlined,
                        accentColor: AppColors.agingMedium,
                        onTap: () => _toggleFilter('medium'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SizedBox(
                      height: 104,
                      child: KpiCard(
                        label: '15+ jours',
                        value: '$_urgentCount',
                        icon: Icons.error_outline,
                        accentColor: AppColors.agingUrgent,
                        onTap: () => _toggleFilter('urgent'),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Active filter chip with "Effacer" ──
            if (_agingFilter != null)
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
                        'Filtré : ${_filterLabel(_agingFilter!)}',
                        style: AppTypography.caption,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _agingFilter = null),
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
              items: _visibleItems,
              isLoading: _loading,
              isLoadingMore: _loadingMore,
              hasMore: _nextCursor != null,
              error: _error,
              onRetry: _load,
              onRefresh: _load,
              onLoadMore: _loadMore,
              emptyTitle: _agingFilter == null
                  ? 'Aucun dossier en attente'
                  : 'Aucun dossier dans cette tranche',
              emptyMessage: _agingFilter == null
                  ? 'Aucun travail revenu du laboratoire n\'attend de pose.'
                  : 'Essayez une autre tranche d\'ancienneté.',
              emptyIcon: Icons.hourglass_empty,
              itemBuilder: (context, item, index) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AnimatedListItem(
                  index: index,
                  child: ProstheticCaseTile(
                    item: item,
                    onTap: () => context.push(Routes.prostheticDetail(item.id)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
