import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/storage/outbox/outbox_item.dart';
import '../../../../core/storage/outbox/outbox_operation.dart';
import '../../../../core/storage/outbox/outbox_store.dart';
import '../../../../core/sync/connectivity_service.dart';
import '../../../../core/sync/sync_status_cubit.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../datasources/label_usage_remote_datasource.dart';
import '../models/label_usage_data.dart';

class LabelUsageRepository {
  final LabelUsageRemoteDatasource _remote;
  final OutboxStore _outbox;
  final ConnectivityService _connectivity;
  final SyncStatusCubit _syncStatus;

  LabelUsageRepository(
    this._remote, {
    required OutboxStore outbox,
    required ConnectivityService connectivity,
    required SyncStatusCubit syncStatus,
  })  : _outbox = outbox,
        _connectivity = connectivity,
        _syncStatus = syncStatus;

  /// Online-first with an offline outbox fallback — same pattern as
  /// StockRepository. This is the single most important write in the
  /// app (Phase 5's "makes or breaks it" feature): a practitioner
  /// recording a device's usage on a patient must never be blocked or
  /// lost because the clinic's wifi dropped.
  Future<LabelUsageData> recordUsage({
    required String labelId,
    required String patientId,
    required String patientName,
    required String practitionerId,
    required String practitionerName,
    required String procedure,
    String? notes,
    DateTime? usedAt,
  }) async {
    final payload = {
      'patient_id': patientId,
      'practitioner_id': practitionerId,
      'procedure': procedure,
      if (notes != null) 'notes': notes,
      if (usedAt != null) 'used_at': usedAt.toIso8601String(),
    };

    final isOnline = await _connectivity.isConnected;
    if (isOnline) {
      try {
        return await _remote.recordUsage(labelId: labelId, payload: payload);
      } on ApiException catch (e) {
        // Network or timeout → fall through to the outbox.
        // Any other error (400, 403, 404, 409, 422) → rethrow, the
        // caller (the form) needs to show it, not silently queue it.
        if (!e.isNetwork && !e.isTimeout) rethrow;
      }
    }

    final itemId = generateIdempotencyKey();
    final item = OutboxItem(
      id: itemId,
      operation: OutboxOperation.labelUsage,
      endpoint: ApiEndpoints.labelUsage(labelId),
      method: 'POST',
      payload: payload,
      idempotencyKey: generateIdempotencyKey(),
      createdAt: DateTime.now(),
    );
    await _outbox.enqueue(item);
    _syncStatus.refreshNow();

    final now = usedAt ?? DateTime.now();
    return LabelUsageData(
      id: itemId,
      labelId: labelId,
      patientId: patientId,
      patientName: patientName,
      practitionerId: practitionerId,
      practitionerName: practitionerName,
      procedure: procedure,
      notes: notes,
      usedAt: now,
    );
  }

  Future<List<LabelUsageData>> history(String labelId) =>
      _remote.fetchHistory(labelId);
}
