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
  final String type; // low_stock, near_expiry, expired, cycle_failed...
  final AlertSeverity severity;
  final String message;
  final DateTime createdAt;
  final bool resolved;
  final String? subjectId; // batch id / cycle id / product id
  final String? subjectLabel; // "LOT-GEL-2026-01" / "Cycle #91"

  const AlertData({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    required this.createdAt,
    required this.resolved,
    this.subjectId,
    this.subjectLabel,
  });

  factory AlertData.fromJson(Map<String, dynamic> json) {
    return AlertData(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'unknown',
      severity: _severityFromString(json['severity']?.toString()),
      message: json['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      resolved: json['resolved'] as bool? ?? false,
      subjectId: json['subject_id']?.toString(),
      subjectLabel: json['subject_label']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        severity,
        message,
        createdAt,
        resolved,
        subjectId,
        subjectLabel,
      ];
}
