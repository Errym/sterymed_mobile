import 'package:equatable/equatable.dart';
import '../../../../core/utils/server_time.dart';

class EvidenceSearchResultData extends Equatable {
  final String labelId;
  final String labelStatus;
  final int cycleNumber;
  final String deviceName;
  final String siteName;
  final String operatorName;
  final String? batchNumber;
  final String patientReference;
  final String practitionerName;
  final String procedure;
  final DateTime usedAt;

  const EvidenceSearchResultData({
    required this.labelId,
    required this.labelStatus,
    required this.cycleNumber,
    required this.deviceName,
    required this.siteName,
    required this.operatorName,
    this.batchNumber,
    required this.patientReference,
    required this.practitionerName,
    required this.procedure,
    required this.usedAt,
  });

  factory EvidenceSearchResultData.fromJson(Map<String, dynamic> json) =>
      EvidenceSearchResultData(
        labelId: json['label_id']?.toString() ?? '',
        labelStatus: json['label_status']?.toString() ?? '',
        cycleNumber: (json['cycle_number'] as num?)?.toInt() ?? 0,
        deviceName: json['device_name']?.toString() ?? '',
        siteName: json['site_name']?.toString() ?? '',
        operatorName: json['operator_name']?.toString() ?? '',
        batchNumber: json['batch_number']?.toString(),
        patientReference: json['patient_reference']?.toString() ?? '',
        practitionerName: json['practitioner_name']?.toString() ?? '',
        procedure: json['procedure']?.toString() ?? '',
        usedAt: parseServerTime(json['used_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  @override
  List<Object?> get props => [labelId, usedAt];
}
