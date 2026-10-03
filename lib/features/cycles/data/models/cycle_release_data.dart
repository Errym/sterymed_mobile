import 'package:equatable/equatable.dart';
import '../../../../core/utils/server_time.dart';

enum CycleReleaseDecision { compliant, rejected }

CycleReleaseDecision _decisionFromString(String? s) => s == 'compliant'
    ? CycleReleaseDecision.compliant
    : CycleReleaseDecision.rejected;

class CycleReleaseData extends Equatable {
  final String id;
  final String cycleId;
  final CycleReleaseDecision decision;
  final String? reason;
  final String? releasedByName;
  final DateTime releasedAt;

  /// True when queued via the offline outbox rather than confirmed by the
  /// server. Backend never sends `is_queued`; the repository sets it.
  final bool isQueued;

  const CycleReleaseData({
    required this.id,
    required this.cycleId,
    required this.decision,
    this.reason,
    this.releasedByName,
    required this.releasedAt,
    this.isQueued = false,
  });

  factory CycleReleaseData.fromJson(Map<String, dynamic> json) {
    return CycleReleaseData(
      id: json['id']?.toString() ?? '',
      cycleId: json['cycle_id']?.toString() ?? '',
      decision: _decisionFromString(json['decision']?.toString()),
      reason: json['reason']?.toString(),
      releasedByName: json['released_by_name']?.toString(),
      releasedAt: parseServerTime(json['released_at']?.toString() ?? '') ??
          DateTime.now(),
      isQueued: json['is_queued'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props =>
      [id, cycleId, decision, reason, releasedByName, releasedAt, isQueued];
}

extension CycleReleaseDecisionLabel on CycleReleaseDecision {
  String get label =>
      this == CycleReleaseDecision.compliant ? 'Conforme — libéré' : 'Rejeté';
}
