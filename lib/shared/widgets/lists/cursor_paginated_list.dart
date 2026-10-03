import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../feedback/empty_view.dart';
import '../feedback/error_view.dart';
import '../feedback/loading_view.dart';

typedef ItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  int index,
);
typedef LoadMoreCallback = Future<void> Function();

class CursorPaginatedList<T> extends StatefulWidget {
  final List<T> items;
  final ItemBuilder<T> itemBuilder;
  final LoadMoreCallback? onLoadMore;
  final Future<void> Function()? onRefresh;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final VoidCallback? onRetry;
  final String emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;
  final EdgeInsets padding;

  const CursorPaginatedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.onLoadMore,
    this.onRefresh,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.onRetry,
    this.emptyTitle = 'Aucun élément',
    this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  @override
  State<CursorPaginatedList<T>> createState() => _CursorPaginatedListState<T>();
}

class _CursorPaginatedListState<T> extends State<CursorPaginatedList<T>> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final threshold = _controller.position.maxScrollExtent - 200;
    if (_controller.position.pixels >= threshold &&
        widget.hasMore &&
        !widget.isLoadingMore) {
      widget.onLoadMore?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.items.isEmpty) {
      return const LoadingView();
    }

    if (widget.error != null && widget.items.isEmpty) {
      return ErrorView(message: widget.error!, onRetry: widget.onRetry);
    }

    if (widget.items.isEmpty) {
      return EmptyView(
        title: widget.emptyTitle,
        message: widget.emptyMessage,
        icon: widget.emptyIcon,
      );
    }

    final stale = widget.error != null;
    final list = ListView.separated(
      controller: _controller,
      padding: widget.padding,
      itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index >= widget.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return widget.itemBuilder(context, widget.items[index], index);
      },
    );

    final body = widget.onRefresh != null
        ? RefreshIndicator(onRefresh: widget.onRefresh!, child: list)
        : list;

    // Rows are on screen but the last load failed: the list may be out of
    // date, and the user has to be told rather than left to assume.
    if (!stale) return body;
    return Column(
      children: [
        Container(
          key: const Key('list-stale-banner'),
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            0,
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.warningLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.error!,
                  style: AppTypography.caption,
                ),
              ),
              if (widget.onRetry != null)
                TextButton(
                  onPressed: widget.onRetry,
                  child: const Text('Réessayer'),
                ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
