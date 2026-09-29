import 'package:equatable/equatable.dart';

class LabelUsageData extends Equatable {
  final String id;
  final String labelId;
  final String patientId;
  final String patientReference;
  final String practitionerId;
  final String? practitionerName;
  final String procedure;
  final String? notes;
  final DateTime usedAt;

  /// True when queued via the offline outbox rather than confirmed by the
  /// server. Backend never sends `is_queued`; the repository sets it.
  final bool isQueued;

  const LabelUsageData({
    required this.id,
    required this.labelId,
    required this.patientId,
    required this.patientReference,
    required this.practitionerId,
    this.practitionerName,
    required this.procedure,
    this.notes,
    required this.usedAt,
    this.isQueued = false,
  });

  factory LabelUsageData.fromJson(Map<String, dynamic> json) {
    return LabelUsageData(
      id: json['id']?.toString() ?? '',
      labelId: json['label_id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      patientReference: json['patient_reference']?.toString() ?? '',
      practitionerId: json['practitioner_id']?.toString() ?? '',
      practitionerName: json['practitioner_name']?.toString(),
      procedure: json['procedure']?.toString() ?? '',
      notes: json['notes']?.toString(),
      usedAt: DateTime.tryParse(json['used_at']?.toString() ?? '') ??
          DateTime.now(),
      isQueued: json['is_queued'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        labelId,
        patientId,
        patientReference,
        practitionerId,
        practitionerName,
        procedure,
        notes,
        usedAt,
        isQueued,
      ];
}