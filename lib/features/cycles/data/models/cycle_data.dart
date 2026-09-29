import 'package:equatable/equatable.dart';

class CycleData extends Equatable {
  final String id;
  final String number;
  final String status;
  final String deviceId;
  final String deviceName;
  final String? deviceProgramId;
  final String? programName;
  final int? programTemperatureCelsius;
  final int? programPlateauMinutes;
  final String? operatorName;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? releasedAt;
  final String? notes;

  /// True when this cycle result was produced by the offline outbox path
  /// (a queued transition) rather than a real server response. Backend
  /// never sends `is_queued`; the repository sets it on the synthetic result.
  final bool isQueued;

  const CycleData({
    required this.id,
    required this.number,
    required this.status,
    required this.deviceId,
    required this.deviceName,
    this.deviceProgramId,
    this.programName,
    this.programTemperatureCelsius,
    this.programPlateauMinutes,
    this.operatorName,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.releasedAt,
    this.notes,
    this.isQueued = false,
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

    // Status: normalize backend's CycleStatus enum (draft, running,
    // completed, awaiting_release, released, rejected — see steriqore's
    // App\Domain\Sterilization\Enums\CycleStatus) to what the UI switches
    // on. draft→created was already handled here; running→in_progress was
    // missing entirely, so every cycle got stuck showing "Démarrer le
    // cycle" forever after a real start() — caught by a real device run
    // of the cycle lifecycle journey test.
    var status = pick(['status', 'state']) ?? 'created';
    if (status == 'draft') status = 'created';
    if (status == 'running') status = 'in_progress';

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
      isQueued: json['is_queued'] as bool? ?? false,
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
    int? programTemperatureCelsius,
    int? programPlateauMinutes,
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
      programTemperatureCelsius:
          programTemperatureCelsius ?? this.programTemperatureCelsius,
      programPlateauMinutes:
          programPlateauMinutes ?? this.programPlateauMinutes,
      operatorName: operatorName ?? this.operatorName,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt,
      releasedAt: releasedAt,
      notes: notes,
      isQueued: isQueued,
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
        programTemperatureCelsius,
        programPlateauMinutes,
        operatorName,
        createdAt,
        startedAt,
        completedAt,
        releasedAt,
        notes,
        isQueued,
      ];
}
