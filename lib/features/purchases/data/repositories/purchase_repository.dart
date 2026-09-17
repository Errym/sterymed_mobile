import '../../../../core/cache/cache.dart';
import '../datasources/purchase_remote_datasource.dart';
import '../models/goods_receipt_data.dart';
import '../models/purchase_order_data.dart';
import '../models/supplier_data.dart';

class PurchaseRepository {
  final PurchaseRemoteDatasource _remote;
  final AppCache _cache;

  PurchaseRepository(this._remote, this._cache);

  Future<List<PurchaseOrderData>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<PurchaseOrderData>>('purchase_orders');
      if (cached != null) return cached;
    }
    final fresh = await _remote.listOrders();
    _cache.put('purchase_orders', fresh);
    return fresh;
  }

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

  Future<GoodsReceiptData> receive({
    required String poId,
    required String locationId,
    required List<Map<String, dynamic>> lines,
  }) async {
    final r = await _remote.receive(
      poId: poId,
      locationId: locationId,
      lines: lines,
    );
    _cache.invalidateAll();
    return r;
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
