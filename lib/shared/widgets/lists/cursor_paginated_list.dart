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
      return EmptyView(title: widget.emptyTitle, message: widget.emptyMessage);
    }

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

    if (widget.onRefresh != null) {
      return RefreshIndicator(onRefresh: widget.onRefresh!, child: list);
    }

    return list;
  }
}
