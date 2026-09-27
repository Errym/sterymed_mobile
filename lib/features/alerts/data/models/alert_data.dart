import 'package:equatable/equatable.dart';

/// The three severity levels the backend uses.
/// Mirror the enum on the server — do not invent.
enum AlertSeverity { critical, warning, info, unknown }

AlertSeverity _severityFromString(String? s) {
  switch (s) {
    case 'critical':
      return AlertSeverity.critical;
    case 'warning':
      return AlertSeverity.warning;
    case 'info':
      return AlertSeverity.info;
    default:
      return AlertSeverity.unknown;
  }
}

extension AlertSeverityLabel on AlertSeverity {
  String get label {
    switch (this) {
      case AlertSeverity.critical:
        return 'Critique';
      case AlertSeverity.warning:
        return 'Avertissement';
      case AlertSeverity.info:
        return 'Information';
      case AlertSeverity.unknown:
        return 'Inconnu';
    }
  }
}

class AlertData extends Equatable {
  final String id;
  final String type; // low_stock, near_expiry, expired, failed_cycle
  final AlertSeverity severity;
  final String state; // open, resolved
  final String subjectType;
  final String? subjectId; // batch id / cycle id / product id
  final String message;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedByName;

  const AlertData({
    required this.id,
    required this.type,
    required this.severity,
    required this.state,
    required this.subjectType,
    this.subjectId,
    required this.message,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedByName,
  });

  bool get resolved => state == 'resolved';

  factory AlertData.fromJson(Map<String, dynamic> json) {
    return AlertData(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'unknown',
      severity: _severityFromString(json['severity']?.toString()),
      state: json['state']?.toString() ?? 'open',
      subjectType: json['subject_type']?.toString() ?? '',
      subjectId: json['subject_id']?.toString(),
      message: json['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      resolvedAt: DateTime.tryParse(json['resolved_at']?.toString() ?? ''),
      resolvedByName: json['resolved_by_name']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        severity,
        state,
        subjectType,
        subjectId,
        message,
        createdAt,
        resolvedAt,
      ];
}
