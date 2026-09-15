import 'package:equatable/equatable.dart';

class LabelUsageData extends Equatable {
  final String id;
  final String labelId;
  final String patientId;
  final String patientName;
  final String practitionerId;
  final String practitionerName;
  final String procedure;
  final String? notes;
  final DateTime usedAt;

  const LabelUsageData({
    required this.id,
    required this.labelId,
    required this.patientId,
    required this.patientName,
    required this.practitionerId,
    required this.practitionerName,
    required this.procedure,
    this.notes,
    required this.usedAt,
  });

  factory LabelUsageData.fromJson(Map<String, dynamic> json) {
    return LabelUsageData(
      id: json['id']?.toString() ?? '',
      labelId: json['label_id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      patientName: json['patient_name']?.toString() ?? '',
      practitionerId: json['practitioner_id']?.toString() ?? '',
      practitionerName: json['practitioner_name']?.toString() ?? '',
      procedure: json['procedure']?.toString() ?? '',
      notes: json['notes']?.toString(),
      usedAt: DateTime.tryParse(json['used_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        labelId,
        patientId,
        patientName,
        practitionerId,
        practitionerName,
        procedure,
        notes,
        usedAt,
      ];
}