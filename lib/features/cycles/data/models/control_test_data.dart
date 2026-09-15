import 'package:equatable/equatable.dart';

enum ControlTestType { vacuum, bowieDick, helix, biological }

enum ControlTestResult { pass, fail }

ControlTestType _typeFromString(String? s) {
  switch (s) {
    case 'vacuum':
      return ControlTestType.vacuum;
    case 'bowie_dick':
      return ControlTestType.bowieDick;
    case 'helix':
      return ControlTestType.helix;
    case 'biological':
      return ControlTestType.biological;
    default:
      return ControlTestType.vacuum;
  }
}

ControlTestResult _resultFromString(String? s) =>
    s == 'pass' ? ControlTestResult.pass : ControlTestResult.fail;

class ControlTestData extends Equatable {
  final String id;
  final String cycleId;
  final ControlTestType type;
  final ControlTestResult result;
  final DateTime performedAt;
  final String? notes;
  final String? operatorName;

  const ControlTestData({
    required this.id,
    required this.cycleId,
    required this.type,
    required this.result,
    required this.performedAt,
    this.notes,
    this.operatorName,
  });

  factory ControlTestData.fromJson(Map<String, dynamic> json) {
    return ControlTestData(
      id: json['id']?.toString() ?? '',
      cycleId: json['cycle_id']?.toString() ?? '',
      type: _typeFromString(json['type']?.toString()),
      result: _resultFromString(json['result']?.toString()),
      performedAt:
          DateTime.tryParse(json['performed_at']?.toString() ?? '') ??
              DateTime.now(),
      notes: json['notes']?.toString(),
      operatorName: json['operator_name']?.toString(),
    );
  }

  @override
  List<Object?> get props =>
      [id, cycleId, type, result, performedAt, notes, operatorName];
}

extension ControlTestTypeLabel on ControlTestType {
  String get label {
    switch (this) {
      case ControlTestType.vacuum:
        return 'Vide';
      case ControlTestType.bowieDick:
        return 'Bowie-Dick';
      case ControlTestType.helix:
        return 'Hélix';
      case ControlTestType.biological:
        return 'Biologique';
    }
  }
}

extension ControlTestResultLabel on ControlTestResult {
  String get label => this == ControlTestResult.pass ? 'Conforme' : 'Non conforme';
}