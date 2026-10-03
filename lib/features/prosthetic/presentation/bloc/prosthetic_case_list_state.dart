part of 'prosthetic_case_list_bloc.dart';

enum ProstheticCaseListStatus { initial, loading, success, failure }

class ProstheticCaseListState extends Equatable {
  final ProstheticCaseListStatus status;
  final List<ProstheticCaseData> cases;
  final String? error;
  final String? nextCursor;
  final bool isLoadingMore;
  final ProstheticCaseListFilters filters;

  /// Exact server-side total for [filters] (the whole result, not the loaded
  /// page). Null until known, or if the count request failed — the list
  /// itself still works without it.
  final int? total;

  const ProstheticCaseListState({
    this.status = ProstheticCaseListStatus.initial,
    this.cases = const [],
    this.error,
    this.nextCursor,
    this.isLoadingMore = false,
    this.filters = const ProstheticCaseListFilters(),
    this.total,
  });

  bool get hasMore => nextCursor != null;

  ProstheticCaseListState copyWith({
    ProstheticCaseListStatus? status,
    List<ProstheticCaseData>? cases,
    String? error,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isLoadingMore,
    ProstheticCaseListFilters? filters,
    int? total,
    bool clearTotal = false,
  }) {
    return ProstheticCaseListState(
      status: status ?? this.status,
      cases: cases ?? this.cases,
      error: error,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      filters: filters ?? this.filters,
      total: clearTotal ? null : (total ?? this.total),
    );
  }

  @override
  List<Object?> get props =>
      [status, cases, error, nextCursor, isLoadingMore, filters, total];
}
