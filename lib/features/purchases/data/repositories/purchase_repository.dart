import 'dart:typed_data';

import '../../../../core/cache/cache.dart';
import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/cursor_page.dart';
import '../../../../core/storage/outbox/outbox_operation.dart';
import '../../../../core/storage/outbox/outbox_store.dart';
import '../../../../core/sync/connectivity_service.dart';
import '../../../../core/sync/sync_status_cubit.dart';
import '../../../cycles/data/models/cycle_attachment_data.dart';
import '../datasources/purchase_remote_datasource.dart';
import '../models/goods_receipt_data.dart';
import '../models/purchase_order_data.dart';
import '../models/supplier_data.dart';

class PurchaseRepository {
  final PurchaseRemoteDatasource _remote;
  final AppCache _cache;
  final ConnectivityService _connectivity;
  final SyncStatusCubit _syncStatus;

  PurchaseRepository(
    this._remote,
    this._cache, {
    required OutboxStore outbox,
    required this._connectivity,
    required this._syncStatus,
  });

  /// [status] filters on the server (`draft`, `ordered`, `partially_received`,
  /// `received`, `cancelled`); the unfiltered first page is the only one cached.
  Future<CursorPage<PurchaseOrderData>> list({
    bool forceRefresh = false,
    String? status,
  }) async {
    final key = status == null ? 'purchase_orders' : 'purchase_orders:$status';
    if (!forceRefresh) {
      final cached = _cache.get<CursorPage<PurchaseOrderData>>(key);
      if (cached != null) return cached;
    }
    final fresh = await _remote.listOrders(status: status);
    _cache.put(key, fresh);
    return fresh;
  }

  /// Paginated fetches always hit the network — same reasoning as
  /// Alerts/Audit/Cycles.
  Future<CursorPage<PurchaseOrderData>> loadMore(
    String cursor, {
    String? status,
  }) => _remote.listOrders(cursor: cursor, status: status);

  Future<PurchaseOrderData> show(String id) => _remote.show(id);

  Future<PurchaseOrderData> create({
    required String supplierId,
    required List<Map<String, dynamic>> lines,
    DateTime? expectedAt,
  }) async {
    final po = await _remote.create(
      supplierId: supplierId,
      lines: lines,
      expectedAt: expectedAt,
    );
    _invalidateOrders();
    return po;
  }

  /// Edits a draft order (online only: the server refuses it once ordered).
  Future<PurchaseOrderData> update(
    String id, {
    List<Map<String, dynamic>>? lines,
    DateTime? expectedAt,
    bool clearExpectedAt = false,
  }) async {
    final po = await _remote.update(
      id,
      lines: lines,
      expectedAt: expectedAt,
      clearExpectedAt: clearExpectedAt,
    );
    _invalidateOrders();
    return po;
  }

  Future<List<GoodsReceiptData>> receipts(String poId) =>
      _remote.listReceipts(poId);

  Future<List<CycleAttachmentData>> receiptAttachments(String receiptId) =>
      _remote.listReceiptAttachments(receiptId);

  /// Attaches the delivery-note photo to a receipt that the server has already
  /// recorded. Online only; the caller keeps the file so a failure can be
  /// retried without taking the photo again.
  Future<CycleAttachmentData> uploadReceiptProof({
    required String receiptId,
    required String fileName,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) => _remote.uploadReceiptProof(
    receiptId: receiptId,
    fileName: fileName,
    bytes: bytes,
    onProgress: onProgress,
  );

  void _invalidateOrders() {
    _cache.invalidate('purchase_orders');
    for (final s in const [
      'draft',
      'ordered',
      'partially_received',
      'received',
      'cancelled',
    ]) {
      _cache.invalidate('purchase_orders:$s');
    }
  }

  Future<PurchaseOrderData> markOrdered(String id) async {
    final po = await _remote.markOrdered(id);
    _invalidateOrders();
    return po;
  }

  Future<PurchaseOrderData> cancel(String id, {String? reason}) async {
    final po = await _remote.cancel(id, reason: reason);
    _invalidateOrders();
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
    final attempt = await _syncStatus.submit(
      operation: OutboxOperation.goodsReceipt,
      endpoint: ApiEndpoints.purchaseOrderReceipts(poId),
      payload: {'location_id': locationId, 'lines': lines},
      resourceKey: 'purchase:$poId',
      online: await _connectivity.isConnected,
    );
    if (attempt.error != null) throw attempt.error!;
    if (attempt.confirmed) {
      _cache.invalidateAll();
      return GoodsReceiptData.fromJson(
        (attempt.data as Map).cast<String, dynamic>(),
      );
    }
    final itemId = attempt.item.id;
    return GoodsReceiptData(
      id: itemId,
      purchaseOrderId: poId,
      totalLines: lines.length,
      receivedAt: DateTime.now(),
      isQueued: true,
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
