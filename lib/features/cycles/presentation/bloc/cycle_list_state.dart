part of 'cycle_list_bloc.dart';

enum CycleListStatus { initial, loading, success, failure }

class CycleListState extends Equatable {
  final CycleListStatus status;
  final List<CycleData> cycles;
  final String? selectedStatus;
  final String searchQuery;
  final String? error;
  final String? nextCursor;
  final bool isLoadingMore;

  const CycleListState({
    this.status = CycleListStatus.initial,
    this.cycles = const [],
    this.selectedStatus,
    this.searchQuery = '',
    this.error,
    this.nextCursor,
    this.isLoadingMore = false,
  });

  bool get hasMore => nextCursor != null;

  List<CycleData> get filtered {
    var result = selectedStatus == null
        ? cycles
        : cycles.where((c) => c.status == selectedStatus).toList();
    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((c) {
        return c.number.toLowerCase().contains(q) ||
            c.deviceName.toLowerCase().contains(q) ||
            (c.programName?.toLowerCase().contains(q) ?? false) ||
            (c.operatorName?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    return result;
  }

  CycleListState copyWith({
    CycleListStatus? status,
    List<CycleData>? cycles,
    String? selectedStatus,
    String? searchQuery,
    String? error,
    bool clearStatusFilter = false,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isLoadingMore,
  }) {
    return CycleListState(
      status: status ?? this.status,
      cycles: cycles ?? this.cycles,
      // When clearStatusFilter is true, explicitly null out the filter.
      // Otherwise, only override if a new value is provided.
      selectedStatus: clearStatusFilter
          ? null
          : (selectedStatus ?? this.selectedStatus),
      searchQuery: searchQuery ?? this.searchQuery,
      error: error ?? this.error,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
        status,
        cycles,
        selectedStatus,
        searchQuery,
        error,
        nextCursor,
        isLoadingMore,
      ];
}
