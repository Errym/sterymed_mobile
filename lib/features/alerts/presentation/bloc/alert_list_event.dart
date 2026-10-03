part of 'alert_list_bloc.dart';

abstract class AlertListEvent extends Equatable {
  const AlertListEvent();
  @override
  List<Object?> get props => [];
}

/// First load, retry: re-reads with the filters already chosen.
class LoadAlerts extends AlertListEvent {
  const LoadAlerts();
}

class RefreshAlerts extends AlertListEvent {
  const RefreshAlerts();
}

class LoadMoreAlerts extends AlertListEvent {
  const LoadMoreAlerts();
}

/// Changes the type and/or state filter. [state] null means open AND resolved.
class FilterAlerts extends AlertListEvent {
  final String? type;
  final String? state;
  const FilterAlerts({this.type, this.state = 'open'});
  @override
  List<Object?> get props => [type, state];
}

class ResolveAlert extends AlertListEvent {
  final String alertId;
  const ResolveAlert(this.alertId);
  @override
  List<Object> get props => [alertId];
}
