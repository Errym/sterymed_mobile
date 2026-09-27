part of 'prosthetic_case_list_bloc.dart';

enum ProstheticCaseListStatus { initial, loading, success, failure }

class ProstheticCaseListState extends Equatable {
  final ProstheticCaseListStatus status;
  final List<ProstheticCaseData> cases;
  final String? error;
  final String? nextCursor;
  final bool isLoadingMore;
  final ProstheticCaseListFilters filters;

  const ProstheticCaseListState({
    this.status = ProstheticCaseListStatus.initial,
    this.cases = const [],
    this.error,
    this.nextCursor,
    this.isLoadingMore = false,
    this.filters = const ProstheticCaseListFilters(),
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
  }) {
    return ProstheticCaseListState(
      status: status ?? this.status,
      cases: cases ?? this.cases,
      error: error,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      filters: filters ?? this.filters,
    );
  }

  @override
  List<Object?> get props =>
      [status, cases, error, nextCursor, isLoadingMore, filters];
}
