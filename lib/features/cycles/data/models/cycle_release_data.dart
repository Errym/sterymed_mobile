import 'package:equatable/equatable.dart';

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

  const CycleReleaseData({
    required this.id,
    required this.cycleId,
    required this.decision,
    this.reason,
    this.releasedByName,
    required this.releasedAt,
  });

  factory CycleReleaseData.fromJson(Map<String, dynamic> json) {
    return CycleReleaseData(
      id: json['id']?.toString() ?? '',
      cycleId: json['cycle_id']?.toString() ?? '',
      decision: _decisionFromString(json['decision']?.toString()),
      reason: json['reason']?.toString(),
      releasedByName: json['released_by_name']?.toString(),
      releasedAt: DateTime.tryParse(json['released_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [id, cycleId, decision, reason, releasedByName, releasedAt];
}

extension CycleReleaseDecisionLabel on CycleReleaseDecision {
  String get label =>
      this == CycleReleaseDecision.compliant ? 'Conforme — libéré' : 'Rejeté';
}
