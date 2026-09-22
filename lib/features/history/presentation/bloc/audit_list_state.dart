part of 'audit_list_bloc.dart';

enum AuditStatus { initial, loading, success, failure }

class AuditListState extends Equatable {
  final AuditStatus status;
  final List<AuditEventData> events;
  final String? actionFilter;
  final String? error;
  final String? nextCursor;
  final bool isLoadingMore;

  const AuditListState({
    this.status = AuditStatus.initial,
    this.events = const [],
    this.actionFilter,
    this.error,
    this.nextCursor,
    this.isLoadingMore = false,
  });

  bool get hasMore => nextCursor != null;

  AuditListState copyWith({
    AuditStatus? status,
    List<AuditEventData>? events,
    String? actionFilter,
    String? error,
    bool clearFilter = false,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isLoadingMore,
  }) {
    return AuditListState(
      status: status ?? this.status,
      events: events ?? this.events,
      actionFilter: clearFilter ? null : (actionFilter ?? this.actionFilter),
      error: error ?? this.error,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props =>
      [status, events, actionFilter, error, nextCursor, isLoadingMore];
}
