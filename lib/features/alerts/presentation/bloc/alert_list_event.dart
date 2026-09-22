part of 'alert_list_bloc.dart';

abstract class AlertListEvent extends Equatable {
  const AlertListEvent();
  @override
  List<Object?> get props => [];
}

class LoadAlerts extends AlertListEvent {
  const LoadAlerts();
}

class RefreshAlerts extends AlertListEvent {
  const RefreshAlerts();
}

class LoadMoreAlerts extends AlertListEvent {
  const LoadMoreAlerts();
}

class ResolveAlert extends AlertListEvent {
  final String alertId;
  const ResolveAlert(this.alertId);
  @override
  List<Object> get props => [alertId];
}