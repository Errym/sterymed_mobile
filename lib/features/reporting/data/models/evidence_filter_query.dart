import '../../../../core/utils/date_filter.dart';

/// The filters of an evidence search as query parameters. The list and the
/// export both use it, so an export is exactly what the screen shows.
Map<String, dynamic> evidenceFilterQuery({
  String? patientReference,
  int? cycleNumber,
  String? batchNumber,
  DateTime? from,
  DateTime? to,
}) =>
    {
      if (patientReference != null && patientReference.isNotEmpty)
        'patient_reference': patientReference,
      if (cycleNumber != null) 'cycle_number': cycleNumber,
      if (batchNumber != null && batchNumber.isNotEmpty)
        'batch_number': batchNumber,
      if (from != null) 'from': fromParam(from),
      if (to != null) 'to': toParam(to),
    };
