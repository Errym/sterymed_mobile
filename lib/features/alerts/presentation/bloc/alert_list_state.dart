part of 'alert_list_bloc.dart';

enum AlertListStatus { initial, loading, success, failure }

class AlertListState extends Equatable {
  final AlertListStatus status;
  final List<AlertData> alerts;
  final String? error;
  final String? nextCursor;
  final bool isLoadingMore;

  const AlertListState({
    this.status = AlertListStatus.initial,
    this.alerts = const [],
    this.error,
    this.nextCursor,
    this.isLoadingMore = false,
  });

  bool get hasMore => nextCursor != null;

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
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isLoadingMore,
  }) {
    return AlertListState(
      status: status ?? this.status,
      alerts: alerts ?? this.alerts,
      error: error ?? this.error,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props =>
      [status, alerts, error, nextCursor, isLoadingMore];
}
