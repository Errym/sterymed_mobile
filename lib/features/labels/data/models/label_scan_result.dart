import 'package:equatable/equatable.dart';

/// Mirrors steriqore's `App\Domain\Labeling\Enums\LabelStatus` exactly —
/// `created -> printed -> used | expired | recalled | voided`. The
/// backend's own scan action (`ResolveLabelScanAction`) transitions a
/// `Printed` label to `Used` synchronously as part of the scan itself, so
/// a scan response showing `printed` is unusual in practice (it means
/// the scan matched but didn't trigger that transition for some reason),
/// not a distinct "please print first" state — `created` is that state.
enum LabelScanStatus { created, printed, used, expired, recalled, voided, unknown }

LabelScanStatus _statusFromString(String? s) {
  switch (s) {
    case 'created':
      return LabelScanStatus.created;
    case 'printed':
      return LabelScanStatus.printed;
    case 'used':
      return LabelScanStatus.used;
    case 'expired':
      return LabelScanStatus.expired;
    case 'recalled':
      return LabelScanStatus.recalled;
    case 'voided':
      return LabelScanStatus.voided;
    default:
      return LabelScanStatus.unknown;
  }
}

/// The real, flat shape `GET /v1/labels/{code}` returns
/// (`App\Domain\Labeling\Data\LabelScanResultData`) — there is no
/// wrapper object and no nested `label` — every field here is top-level
/// on the response.
class LabelScanResult extends Equatable {
  final String labelId;
  final LabelScanStatus status;
  final int cycleNumber;
  final String deviceName;
  final DateTime sterilizedAt;
  final DateTime useByDate;
  final int sequenceInCycle;
  final String siteName;

  const LabelScanResult({
    required this.labelId,
    required this.status,
    required this.cycleNumber,
    required this.deviceName,
    required this.sterilizedAt,
    required this.useByDate,
    required this.sequenceInCycle,
    required this.siteName,
  });

  /// A usage can only be recorded once the scan has put the label in
  /// `Used` — matches `RecordLabelUsageAction`'s real requirement
  /// (backend error code `LABEL_NOT_SCANNED` otherwise).
  bool get canRecordUsage => status == LabelScanStatus.used;

  factory LabelScanResult.fromJson(Map<String, dynamic> json) {
    return LabelScanResult(
      labelId: json['label_id']?.toString() ?? '',
      status: _statusFromString(json['status']?.toString()),
      cycleNumber: (json['cycle_number'] as num?)?.toInt() ?? 0,
      deviceName: json['device_name']?.toString() ?? '',
      sterilizedAt:
          DateTime.tryParse(json['sterilized_at']?.toString() ?? '') ??
              DateTime.now(),
      useByDate: DateTime.tryParse(json['use_by_date']?.toString() ?? '') ??
          DateTime.now(),
      sequenceInCycle: (json['sequence_in_cycle'] as num?)?.toInt() ?? 0,
      siteName: json['site_name']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [
        labelId,
        status,
        cycleNumber,
        deviceName,
        sterilizedAt,
        useByDate,
        sequenceInCycle,
        siteName,
      ];
}
