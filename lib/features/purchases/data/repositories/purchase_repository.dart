import '../../../../core/cache/cache.dart';
import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/cursor_page.dart';
import '../../../../core/storage/outbox/outbox_item.dart';
import '../../../../core/storage/outbox/outbox_operation.dart';
import '../../../../core/storage/outbox/outbox_store.dart';
import '../../../../core/sync/connectivity_service.dart';
import '../../../../core/sync/sync_status_cubit.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../datasources/purchase_remote_datasource.dart';
import '../models/goods_receipt_data.dart';
import '../models/purchase_order_data.dart';
import '../models/supplier_data.dart';

class PurchaseRepository {
  final PurchaseRemoteDatasource _remote;
  final AppCache _cache;
  final OutboxStore _outbox;
  final ConnectivityService _connectivity;
  final SyncStatusCubit _syncStatus;

  PurchaseRepository(
    this._remote,
    this._cache, {
    required OutboxStore outbox,
    required ConnectivityService connectivity,
    required SyncStatusCubit syncStatus,
  })  : _outbox = outbox,
        _connectivity = connectivity,
        _syncStatus = syncStatus;

  Future<CursorPage<PurchaseOrderData>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<CursorPage<PurchaseOrderData>>('purchase_orders');
      if (cached != null) return cached;
    }
    final fresh = await _remote.listOrders();
    _cache.put('purchase_orders', fresh);
    return fresh;
  }

  /// Paginated fetches always hit the network — same reasoning as
  /// Alerts/Audit/Cycles.
  Future<CursorPage<PurchaseOrderData>> loadMore(String cursor) =>
      _remote.listOrders(cursor: cursor);

  Future<PurchaseOrderData> show(String id) => _remote.show(id);

  Future<PurchaseOrderData> create({
    required String supplierId,
    required List<Map<String, dynamic>> lines,
  }) async {
    final po = await _remote.create(supplierId: supplierId, lines: lines);
    _cache.invalidate('purchase_orders');
    return po;
  }

  Future<PurchaseOrderData> markOrdered(String id) async {
    final po = await _remote.markOrdered(id);
    _cache.invalidate('purchase_orders');
    return po;
  }

  Future<PurchaseOrderData> cancel(String id, {String? reason}) async {
    final po = await _remote.cancel(id, reason: reason);
    _cache.invalidate('purchase_orders');
    return po;
  }

  /// Online-first with an offline outbox fallback — same pattern as
  /// Stock/Label Usage/Cycles. goods_receipt_screen discards the return
  /// value on success (it just navigates back), so the synthetic result
  /// needs no real fidelity.
  Future<GoodsReceiptData> receive({
    required String poId,
    required String locationId,
    required List<Map<String, dynamic>> lines,
  }) async {
    final isOnline = await _connectivity.isConnected;
    if (isOnline) {
      try {
        final r = await _remote.receive(
          poId: poId,
          locationId: locationId,
          lines: lines,
        );
        _cache.invalidateAll();
        return r;
      } on ApiException catch (e) {
        if (!e.isNetwork && !e.isTimeout) rethrow;
      }
    }

    final itemId = generateIdempotencyKey();
    await _outbox.enqueue(OutboxItem(
      id: itemId,
      operation: OutboxOperation.goodsReceipt,
      endpoint: ApiEndpoints.purchaseOrderReceipts(poId),
      method: 'POST',
      payload: {'location_id': locationId, 'lines': lines},
      idempotencyKey: generateIdempotencyKey(),
      createdAt: DateTime.now(),
    ));
    _syncStatus.refreshNow();

    return GoodsReceiptData(
      id: itemId,
      purchaseOrderId: poId,
      totalLines: lines.length,
      receivedAt: DateTime.now(),
    );
  }

  Future<List<SupplierData>> listSuppliers({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<SupplierData>>('suppliers');
      if (cached != null) return cached;
    }
    final fresh = await _remote.listSuppliers();
    _cache.put('suppliers', fresh);
    return fresh;
  }
}
