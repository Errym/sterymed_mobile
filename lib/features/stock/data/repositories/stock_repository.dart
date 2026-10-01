import '../../../../core/cache/cache.dart';
import '../../../../core/storage/outbox/outbox_operation.dart';
import '../../../../core/storage/outbox/outbox_store.dart';
import '../../../../core/sync/connectivity_service.dart';
import '../../../../core/sync/sync_status_cubit.dart';
import '../../../../core/config/api_endpoints.dart';
import '../datasources/stock_remote_datasource.dart';
import '../models/stock_level_data.dart';
import '../models/stock_movement_data.dart';
import '../models/stock_option.dart';

class StockRepository {
  final StockRemoteDatasource _remote;
  final AppCache _cache;
  final ConnectivityService _connectivity;
  final SyncStatusCubit _syncStatus;

  StockRepository(
    this._remote,
    this._cache, {
    required OutboxStore outbox,
    required this._connectivity,
    required this._syncStatus,
  });

  // ─────────────────────────────────────────────────────────────
  // Reads (always try network, fall back to cache)
  // ─────────────────────────────────────────────────────────────

  Future<List<StockLevelData>> listLevels({
    String? search,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && (search == null || search.trim().isEmpty)) {
      final cached = _cache.get<List<StockLevelData>>('stock_levels');
      if (cached != null) return cached;
    }
    final fresh = await _remote.listLevels(search: search);
    if (search == null || search.trim().isEmpty) {
      _cache.put('stock_levels', fresh);
    }
    return fresh;
  }

  Future<({List<StockOption> batches, List<StockOption> locations})>
  listOptions({bool forceRefresh = false}) async {
    const key = 'stock_options';
    if (!forceRefresh) {
      final cached = _cache
          .get<({List<StockOption> batches, List<StockOption> locations})>(key);
      if (cached != null) return cached;
    }
    final fresh = await _remote.listOptions();
    _cache.put(key, fresh);
    return fresh;
  }

  // ─────────────────────────────────────────────────────────────
  // Writes — all route through _submitWrite
  // ─────────────────────────────────────────────────────────────

  Future<StockMovementData> issue({
    required String batchId,
    required String locationId,
    required int qty,
    String? reason,
  }) async {
    return _submitWrite(
      operation: OutboxOperation.stockIssue,
      endpoint: ApiEndpoints.stockIssue,
      payload: {
        'batch_id': batchId,
        'location_id': locationId,
        'qty': qty,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
      synthetic: (id) => StockMovementData(
        id: id,
        kind: 'issue',
        batchId: batchId,
        locationId: locationId,
        qty: qty,
        reason: reason,
        createdAt: DateTime.now(),
        isQueued: true,
      ),
    );
  }

  Future<StockMovementData> adjust({
    required String batchId,
    required String locationId,
    required int qty,
    required String reason,
  }) async {
    return _submitWrite(
      operation: OutboxOperation.stockAdjust,
      endpoint: ApiEndpoints.stockAdjust,
      payload: {
        'batch_id': batchId,
        'location_id': locationId,
        'qty': qty,
        'reason': reason.trim(),
      },
      synthetic: (id) => StockMovementData(
        id: id,
        kind: 'adjust',
        batchId: batchId,
        locationId: locationId,
        qty: qty,
        reason: reason,
        createdAt: DateTime.now(),
        isQueued: true,
      ),
    );
  }

  Future<StockMovementData> transfer({
    required String batchId,
    required String fromLocationId,
    required String toLocationId,
    required int qty,
    String? reason,
  }) async {
    return _submitWrite(
      operation: OutboxOperation.stockTransfer,
      endpoint: ApiEndpoints.stockTransfer,
      payload: {
        'batch_id': batchId,
        'from_location_id': fromLocationId,
        'to_location_id': toLocationId,
        'qty': qty,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
      synthetic: (id) => StockMovementData(
        id: id,
        kind: 'transfer',
        batchId: batchId,
        locationId: fromLocationId,
        qty: qty,
        reason: reason,
        createdAt: DateTime.now(),
        isQueued: true,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // The one method all writes go through
  // ─────────────────────────────────────────────────────────────

  Future<StockMovementData> _submitWrite({
    required OutboxOperation operation,
    required String endpoint,
    required Map<String, dynamic> payload,
    required StockMovementData Function(String id) synthetic,
  }) async {
    final attempt = await _syncStatus.submit(
      operation: operation,
      endpoint: endpoint,
      payload: payload,
      resourceKey: 'stock:${payload['batch_id']}',
      online: await _connectivity.isConnected,
    );
    if (attempt.error != null) throw attempt.error!;
    if (!attempt.confirmed) return synthetic(attempt.item.id);
    _invalidateStockCaches();
    final raw = operation == OutboxOperation.stockTransfer
        ? (attempt.data as Map)['debit']
        : attempt.data;
    return StockMovementData.fromJson((raw as Map).cast<String, dynamic>());
  }

  void _invalidateStockCaches() {
    _cache.invalidate('stock_levels');
    _cache.invalidate('stock_options');
    _cache.invalidate('dashboard');
  }
}
