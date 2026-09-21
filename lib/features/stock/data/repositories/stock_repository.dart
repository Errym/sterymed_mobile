import '../../../../core/cache/cache.dart';
import '../../../../core/storage/outbox/outbox_item.dart';
import '../../../../core/storage/outbox/outbox_operation.dart';
import '../../../../core/storage/outbox/outbox_store.dart';
import '../../../../core/sync/connectivity_service.dart';
import '../../../../core/sync/sync_status_cubit.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/config/api_endpoints.dart';
import '../datasources/stock_remote_datasource.dart';
import '../models/stock_level_data.dart';
import '../models/stock_movement_data.dart';
import '../models/stock_option.dart';

class StockRepository {
  final StockRemoteDatasource _remote;
  final AppCache _cache;
  final OutboxStore _outbox;
  final ConnectivityService _connectivity;
  final SyncStatusCubit _syncStatus;

  StockRepository(
    this._remote,
    this._cache, {
    required OutboxStore outbox,
    required ConnectivityService connectivity,
    required SyncStatusCubit syncStatus,
  })  : _outbox = outbox,
        _connectivity = connectivity,
        _syncStatus = syncStatus;

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
          .get<({List<StockOption> batches, List<StockOption> locations})>(
              key);
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
      online: () => _remote.issue(
        batchId: batchId,
        locationId: locationId,
        qty: qty,
        reason: reason,
      ),
      synthetic: (id) => StockMovementData(
        id: id,
        kind: 'issue',
        batchId: batchId,
        locationId: locationId,
        qty: qty,
        reason: reason,
        createdAt: DateTime.now(),
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
      online: () => _remote.adjust(
        batchId: batchId,
        locationId: locationId,
        qty: qty,
        reason: reason,
      ),
      synthetic: (id) => StockMovementData(
        id: id,
        kind: 'adjust',
        batchId: batchId,
        locationId: locationId,
        qty: qty,
        reason: reason,
        createdAt: DateTime.now(),
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
      online: () => _remote.transfer(
        batchId: batchId,
        fromLocationId: fromLocationId,
        toLocationId: toLocationId,
        qty: qty,
        reason: reason,
      ),
      synthetic: (id) => StockMovementData(
        id: id,
        kind: 'transfer',
        batchId: batchId,
        locationId: fromLocationId,
        qty: qty,
        reason: reason,
        createdAt: DateTime.now(),
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
    required Future<StockMovementData> Function() online,
    required StockMovementData Function(String id) synthetic,
  }) async {
    // 1. Try online
    final isOnline = await _connectivity.isConnected;
    if (isOnline) {
      try {
        final result = await online();
        _invalidateStockCaches();
        return result;
      } on ApiException catch (e) {
        // Network or timeout → fall through to offline
        // Any other error (400, 403, 404, 409, 422) → rethrow
        if (!e.isNetwork && !e.isTimeout) rethrow;
        // Otherwise fall through to outbox
      }
    }

    // 2. Offline path — queue and return synthetic success
    final itemId = generateIdempotencyKey();
    final item = OutboxItem(
      id: itemId,
      operation: operation,
      endpoint: endpoint,
      method: 'POST',
      payload: payload,
      idempotencyKey: generateIdempotencyKey(),
      createdAt: DateTime.now(),
    );

    await _outbox.enqueue(item);
    _syncStatus.refreshNow();

    return synthetic(itemId);
  }

  void _invalidateStockCaches() {
    _cache.invalidate('stock_levels');
    _cache.invalidate('stock_options');
    _cache.invalidate('dashboard');
  }
}
