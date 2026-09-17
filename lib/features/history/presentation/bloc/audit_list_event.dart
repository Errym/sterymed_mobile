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

class FilterAuditEvents extends AuditListEvent {
  final String? action;
  const FilterAuditEvents(this.action);
  @override
  List<Object?> get props => [action];
}
