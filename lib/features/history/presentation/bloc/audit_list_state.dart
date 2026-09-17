part of 'audit_list_bloc.dart';

enum AuditStatus { initial, loading, success, failure }

class AuditListState extends Equatable {
  final AuditStatus status;
  final List<AuditEventData> events;
  final String? actionFilter;
  final String? error;

  const AuditListState({
    this.status = AuditStatus.initial,
    this.events = const [],
    this.actionFilter,
    this.error,
  });

  AuditListState copyWith({
    AuditStatus? status,
    List<AuditEventData>? events,
    String? actionFilter,
    String? error,
    bool clearFilter = false,
  }) {
    return AuditListState(
      status: status ?? this.status,
      events: events ?? this.events,
      actionFilter: clearFilter ? null : (actionFilter ?? this.actionFilter),
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, events, actionFilter, error];
}
