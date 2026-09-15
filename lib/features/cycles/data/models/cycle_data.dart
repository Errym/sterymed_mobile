import 'package:equatable/equatable.dart';

class CycleData extends Equatable {
  final String id;
  final String number;
  final String
      status; // created, in_progress, completed, awaiting_release, released, rejected
  final String deviceId;
  final String deviceName;
  final String? programName;
  final String? operatorName;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? releasedAt;
  final String? notes;

  const CycleData({
    required this.id,
    required this.number,
    required this.status,
    required this.deviceId,
    required this.deviceName,
    this.programName,
    this.operatorName,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.releasedAt,
    this.notes,
  });

  factory CycleData.fromJson(Map<String, dynamic> json) {
    return CycleData(
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      status: json['status']?.toString() ?? 'created',
      deviceId: json['device_id']?.toString() ?? '',
      deviceName: json['device_name']?.toString() ?? '',
      programName: json['program_name']?.toString(),
      operatorName: json['operator_name']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? ''),
      completedAt: DateTime.tryParse(json['completed_at']?.toString() ?? ''),
      releasedAt: DateTime.tryParse(json['released_at']?.toString() ?? ''),
      notes: json['notes']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        number,
        status,
        deviceId,
        deviceName,
        programName,
        operatorName,
        createdAt,
        startedAt,
        completedAt,
        releasedAt,
        notes,
      ];
}
