import '../datasources/label_usage_remote_datasource.dart';
import '../models/label_usage_data.dart';

class LabelUsageRepository {
  final LabelUsageRemoteDatasource _remote;
  LabelUsageRepository(this._remote);

  Future<LabelUsageData> recordUsage({
    required String labelId,
    required String patientId,
    required String practitionerId,
    required String procedure,
    String? notes,
    DateTime? usedAt,
  }) {
    return _remote.recordUsage(
      labelId: labelId,
      payload: {
        'patient_id': patientId,
        'practitioner_id': practitionerId,
        'procedure': procedure,
        if (notes != null) 'notes': notes,
        if (usedAt != null) 'used_at': usedAt.toIso8601String(),
      },
    );
  }

  Future<List<LabelUsageData>> history(String labelId) =>
      _remote.fetchHistory(labelId);
}
