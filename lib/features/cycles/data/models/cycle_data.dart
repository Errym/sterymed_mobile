import 'package:equatable/equatable.dart';

class CycleData extends Equatable {
  final String id;
  final String number;
  final String status;
  final String deviceId;
  final String deviceName;
  final String? deviceProgramId;
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
    this.deviceProgramId,
    this.programName,
    this.operatorName,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.releasedAt,
    this.notes,
  });

  factory CycleData.fromJson(Map<String, dynamic> json) {
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return null;
    }

    final id = pick(['id', 'uuid']) ?? '';

    // Number: cycle_number, number, reference, code — fallback to id prefix
    final rawNumber = pick(['cycle_number', 'number', 'reference', 'code']);
    final number = rawNumber ??
        (id.isNotEmpty ? 'CT-${id.substring(0, 6).toUpperCase()}' : 'CT-?');

    // Status: normalize draft→created
    var status = pick(['status', 'state']) ?? 'created';
    if (status == 'draft') status = 'created';

    // Device: name may be nested under "device" or separate "device_name"
    String? deviceName = pick(['device_name', 'device_label']);
    if (deviceName == null && json['device'] is Map) {
      final d = (json['device'] as Map).cast<String, dynamic>();
      deviceName = pick(['name', 'label']);
      if (deviceName == null) {
        final n = d['name'];
        if (n != null) deviceName = n.toString();
      }
    }
    // If still null, leave empty for now — the repo will join from cache
    deviceName ??= '';

    // Device program: same treatment
    final deviceProgramId =
        pick(['device_program_id', 'program_id', 'programme_id']);

    String? programName = pick(['program_name', 'programme_name']);
    if (programName == null && json['program'] is Map) {
      final p = (json['program'] as Map).cast<String, dynamic>();
      final n = p['name'];
      if (n != null) programName = n.toString();
    }

    // Operator
    String? operatorName = pick(['operator_name', 'operator_label']);
    if (operatorName == null && json['operator'] is Map) {
      final o = (json['operator'] as Map).cast<String, dynamic>();
      final n = o['name'];
      if (n != null) operatorName = n.toString();
    }

    return CycleData(
      id: id,
      number: number,
      status: status,
      deviceId: pick(['device_id']) ?? '',
      deviceName: deviceName,
      deviceProgramId: deviceProgramId,
      programName: programName,
      operatorName: operatorName,
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      startedAt: _parseDate(json['started_at']),
      completedAt: _parseDate(json['completed_at']),
      releasedAt: _parseDate(json['released_at']),
      notes: json['notes']?.toString(),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  /// Used by the repository to inject resolved names after lookup.
  CycleData copyWithNames({
    String? deviceName,
    String? programName,
    String? operatorName,
  }) {
    return CycleData(
      id: id,
      number: number,
      status: status,
      deviceId: deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceProgramId: deviceProgramId,
      programName: programName ?? this.programName,
      operatorName: operatorName ?? this.operatorName,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt,
      releasedAt: releasedAt,
      notes: notes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        number,
        status,
        deviceId,
        deviceName,
        deviceProgramId,
        programName,
        operatorName,
        createdAt,
        startedAt,
        completedAt,
        releasedAt,
        notes,
      ];
}
