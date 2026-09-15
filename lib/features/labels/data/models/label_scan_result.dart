import 'package:equatable/equatable.dart';

import 'label_data.dart';

/// Server-side status of a label. Never compute expiry client-side.
enum LabelScanStatus { valid, expired, recalled, unknown }

LabelScanStatus _statusFromString(String? s) {
  switch (s) {
    case 'valid':
      return LabelScanStatus.valid;
    case 'expired':
      return LabelScanStatus.expired;
    case 'recalled':
      return LabelScanStatus.recalled;
    default:
      return LabelScanStatus.unknown;
  }
}

class LabelScanResult extends Equatable {
  final String code;
  final LabelScanStatus status;
  final String? reason;
  final LabelData? label;

  const LabelScanResult({
    required this.code,
    required this.status,
    this.reason,
    this.label,
  });

  bool get isBlocked =>
      status == LabelScanStatus.expired || status == LabelScanStatus.recalled;

  factory LabelScanResult.fromJson(Map<String, dynamic> json) {
    final labelJson = json['label'];
    return LabelScanResult(
      code: json['code']?.toString() ?? '',
      status: _statusFromString(json['status']?.toString()),
      reason: json['reason']?.toString(),
      label: labelJson is Map<String, dynamic>
          ? LabelData.fromJson(labelJson)
          : null,
    );
  }

  @override
  List<Object?> get props => [code, status, reason, label];
}
