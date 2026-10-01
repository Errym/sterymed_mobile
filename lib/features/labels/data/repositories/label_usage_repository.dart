import '../../../../core/config/api_endpoints.dart';
import '../../../../core/storage/outbox/outbox_operation.dart';
import '../../../../core/storage/outbox/outbox_store.dart';
import '../../../../core/sync/connectivity_service.dart';
import '../../../../core/sync/sync_status_cubit.dart';
import '../datasources/label_usage_remote_datasource.dart';
import '../models/label_usage_data.dart';

class LabelUsageRepository {
  final LabelUsageRemoteDatasource _remote;
  final ConnectivityService _connectivity;
  final SyncStatusCubit _syncStatus;

  LabelUsageRepository(
    this._remote, {
    required OutboxStore outbox,
    required this._connectivity,
    required this._syncStatus,
  });

  /// Online-first with an offline outbox fallback — same pattern as
  /// StockRepository. This is the single most important write in the
  /// app (Phase 5's "makes or breaks it" feature): a practitioner
  /// recording a device's usage on a patient must never be blocked or
  /// lost because the clinic's wifi dropped.
  Future<LabelUsageData> recordUsage({
    required String labelId,
    required String patientId,
    required String patientReference,
    required String practitionerId,
    String? practitionerName,
    required String procedure,
    String? notes,
    DateTime? usedAt,
  }) async {
    final occurredAt = usedAt ?? DateTime.now().toUtc();
    final payload = {
      'patient_id': patientId,
      'practitioner_id': practitionerId,
      'procedure': procedure,
      if (notes != null) 'notes': notes,
      'used_at': occurredAt.toUtc().toIso8601String(),
    };

    final attempt = await _syncStatus.submit(
      operation: OutboxOperation.labelUsage,
      endpoint: ApiEndpoints.labelUsage(labelId),
      payload: payload,
      resourceKey: 'label:$labelId',
      online: await _connectivity.isConnected,
    );
    if (attempt.error != null) throw attempt.error!;
    if (attempt.confirmed) {
      return LabelUsageData.fromJson(
        (attempt.data as Map).cast<String, dynamic>(),
      );
    }
    final itemId = attempt.item.id;
    final now = occurredAt;
    return LabelUsageData(
      id: itemId,
      labelId: labelId,
      patientId: patientId,
      patientReference: patientReference,
      practitionerId: practitionerId,
      practitionerName: practitionerName,
      procedure: procedure,
      notes: notes,
      usedAt: now,
      isQueued: true,
    );
  }

  Future<List<LabelUsageData>> history(String labelId) =>
      _remote.fetchHistory(labelId);
}
