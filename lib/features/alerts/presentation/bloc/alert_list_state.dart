part of 'alert_list_bloc.dart';

enum AlertListStatus { initial, loading, success, failure }

/// The one-shot answer to the last "resolve" tap, shown once as a message.
/// [seq] makes two identical answers in a row still count as two.
class AlertNotice extends Equatable {
  final int seq;
  final String message;
  final bool isError;
  const AlertNotice(this.seq, this.message, {this.isError = false});
  @override
  List<Object?> get props => [seq, message, isError];
}

class AlertListState extends Equatable {
  final AlertListStatus status;
  final List<AlertData> alerts;
  final String? error;
  final String? nextCursor;
  final bool isLoadingMore;

  /// Server-side filters. [stateFilter] null = open and resolved.
  final String? typeFilter;
  final String? stateFilter;

  /// Alerts whose "resolve" request is in flight (button disabled, spinner).
  final Set<String> resolving;
  final AlertNotice? notice;

  const AlertListState({
    this.status = AlertListStatus.initial,
    this.alerts = const [],
    this.error,
    this.nextCursor,
    this.isLoadingMore = false,
    this.typeFilter,
    this.stateFilter = 'open',
    this.resolving = const {},
    this.notice,
  });

  bool get hasMore => nextCursor != null;

  bool get hasActiveFilter => typeFilter != null || stateFilter != 'open';

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
    String? typeFilter,
    bool clearTypeFilter = false,
    String? stateFilter,
    bool clearStateFilter = false,
    Set<String>? resolving,
    AlertNotice? notice,
  }) {
    return AlertListState(
      status: status ?? this.status,
      alerts: alerts ?? this.alerts,
      error: error,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      stateFilter: clearStateFilter ? null : (stateFilter ?? this.stateFilter),
      resolving: resolving ?? this.resolving,
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [
        status,
        alerts,
        error,
        nextCursor,
        isLoadingMore,
        typeFilter,
        stateFilter,
        resolving,
        notice,
      ];
}
