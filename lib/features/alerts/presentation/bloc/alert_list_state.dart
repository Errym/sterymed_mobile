part of 'alert_list_bloc.dart';

enum AlertListStatus { initial, loading, success, failure }

class AlertListState extends Equatable {
  final AlertListStatus status;
  final List<AlertData> alerts;
  final String? error;

  const AlertListState({
    this.status = AlertListStatus.initial,
    this.alerts = const [],
    this.error,
  });

  /// Alerts grouped by severity — used by the screen to render sections.
  List<AlertData> get criticalAlerts =>
      alerts.where((a) => a.severity == AlertSeverity.critical).toList();

  List<AlertData> get warningAlerts =>
      alerts.where((a) => a.severity == AlertSeverity.warning).toList();

  List<AlertData> get infoAlerts =>
      alerts.where((a) => a.severity == AlertSeverity.info).toList();

  AlertListState copyWith({
    AlertListStatus? status,
    List<AlertData>? alerts,
    String? error,
  }) {
    return AlertListState(
      status: status ?? this.status,
      alerts: alerts ?? this.alerts,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, alerts, error];
}
