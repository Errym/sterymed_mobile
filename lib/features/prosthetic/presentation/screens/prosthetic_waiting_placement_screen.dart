import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/cursor_page.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/cursor_paginated_list.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/prosthetic_case_data.dart';
import '../../data/repositories/prosthetic_repository.dart';
import '../widgets/prosthetic_case_tile.dart';

/// Brief page 9: "the priority screen specifically requested." Aging is
/// already computed by `ProstheticCaseTile` from `daysWaitingForPlacement`
/// (server-computed, not re-derived here) — the sort order (earliest
/// return date first, from the backend query) does the "0-7/8-14/15+"
/// prioritization implicitly.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'En attente de pose'),
      body: CursorPaginatedList<ProstheticCaseData>(
        items: _items,
        isLoading: _loading,
        isLoadingMore: _loadingMore,
        hasMore: _nextCursor != null,
        error: _error,
        onRetry: _load,
        onRefresh: _load,
        onLoadMore: _loadMore,
        emptyTitle: 'Aucun dossier en attente',
        emptyMessage:
            'Aucun travail revenu du laboratoire n\'attend de pose.',
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
    );
  }
}
