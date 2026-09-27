import 'package:steriymed_mobile/features/labels/data/models/label_scan_result.dart';
import 'package:steriymed_mobile/features/labels/data/models/label_usage_data.dart';

LabelScanResult buildLabelScanResult({
  String labelId = 'label-1',
  LabelScanStatus status = LabelScanStatus.used,
  int cycleNumber = 12,
  String deviceName = 'Autoclave Salle 2',
  String siteName = 'Cabinet Principal',
}) {
  return LabelScanResult(
    labelId: labelId,
    status: status,
    cycleNumber: cycleNumber,
    deviceName: deviceName,
    sterilizedAt: DateTime(2026, 9, 1),
    useByDate: DateTime(2026, 12, 1),
    sequenceInCycle: 1,
    siteName: siteName,
  );
}

LabelUsageData buildLabelUsage({
  String id = 'usage-1',
  String labelId = 'label-1',
  String patientId = 'p1',
  String patientReference = 'PAT-000001',
  String practitionerId = 'prat-1',
  String? practitionerName = 'Dr Test',
  String procedure = 'Détartrage',
}) {
  return LabelUsageData(
    id: id,
    labelId: labelId,
    patientId: patientId,
    patientReference: patientReference,
    practitionerId: practitionerId,
    practitionerName: practitionerName,
    procedure: procedure,
    usedAt: DateTime(2026, 9, 1, 9, 30),
  );
}
