import 'package:equatable/equatable.dart';
import '../../../../core/utils/server_time.dart';

/// Mirrors steriqore's `App\Domain\Equipment\Data\MaintenanceRecordData`.
/// Append-only — the backend exposes no PATCH/DELETE route for this
/// resource, matching the brief's traceability rule (no silent deletion
/// of a compliance record).
class MaintenanceRecordData extends Equatable {
  final String id;
  final String deviceId;
  final String? recordedByUserId;
  final String kind;
  final String? technician;
  final DateTime performedAt;
  final DateTime? nextDueAt;
  final String? description;

  const MaintenanceRecordData({
    required this.id,
    required this.deviceId,
    this.recordedByUserId,
    required this.kind,
    this.technician,
    required this.performedAt,
    this.nextDueAt,
    this.description,
  });

  factory MaintenanceRecordData.fromJson(Map<String, dynamic> json) {
    return MaintenanceRecordData(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      recordedByUserId: json['recorded_by_user_id']?.toString(),
      kind: json['kind']?.toString() ?? 'preventive',
      technician: json['technician']?.toString(),
      performedAt:
          parseServerTime(json['performed_at']?.toString() ?? '') ??
              DateTime.now(),
      nextDueAt: json['next_due_at'] != null
          ? parseServerTime(json['next_due_at'].toString())
          : null,
      description: json['description']?.toString(),
    );
  }

  /// Backend enum `App\Domain\Equipment\Enums\MaintenanceKind`:
  /// preventive, corrective, calibration.
  String get kindLabel => switch (kind) {
        'preventive' => 'Préventive',
        'corrective' => 'Corrective',
        'calibration' => 'Étalonnage',
        _ => kind,
      };

  bool get isOverdue =>
      nextDueAt != null && nextDueAt!.isBefore(DateTime.now());

  @override
  List<Object?> get props => [id, deviceId, kind, performedAt, nextDueAt];
}
