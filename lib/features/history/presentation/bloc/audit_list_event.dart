part of 'audit_list_bloc.dart';

abstract class AuditListEvent extends Equatable {
  const AuditListEvent();
  @override
  List<Object?> get props => [];
}

class LoadAuditEvents extends AuditListEvent {
  const LoadAuditEvents();
}

class RefreshAuditEvents extends AuditListEvent {
  const RefreshAuditEvents();
}

class LoadMoreAuditEvents extends AuditListEvent {
  const LoadMoreAuditEvents();
}

class FilterAuditEvents extends AuditListEvent {
  final String? action;
  const FilterAuditEvents(this.action);
  @override
  List<Object?> get props => [action];
}

class ApplyAdvancedAuditFilters extends AuditListEvent {
  final String? actorId;
  final String? actorLabel;
  final String? subjectType;
  final DateTime? from;
  final DateTime? to;

  const ApplyAdvancedAuditFilters({
    this.actorId,
    this.actorLabel,
    this.subjectType,
    this.from,
    this.to,
  });

  @override
  List<Object?> get props => [actorId, actorLabel, subjectType, from, to];
}
