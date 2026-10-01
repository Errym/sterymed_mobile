import '../../../../core/cache/cache.dart';
import '../datasources/supplier_remote_datasource.dart';
import '../models/supplier_data.dart';
import '../models/supplier_product_data.dart';

class SupplierRepository {
  final SupplierRemoteDatasource _remote;
  final AppCache _cache;

  SupplierRepository(this._remote, this._cache);

  Future<List<SupplierData>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<SupplierData>>('suppliers');
      if (cached != null) return cached;
    }
    final fresh = await _remote.list();
    _cache.put('suppliers', fresh);
    return fresh;
  }

  Future<SupplierData> show(String id) => _remote.show(id);

  Future<SupplierData> create({
    required String name,
    String? email,
    String? phone,
    String? address,
  }) async {
    final s = await _remote.create(
      name: name,
      email: email,
      phone: phone,
      address: address,
    );
    _cache.invalidateAll();
    return s;
  }

  Future<SupplierData> update(
    String id, {
    required String name,
    String? email,
    String? phone,
    String? address,
  }) async {
    final s = await _remote.update(
      id,
      name: name,
      email: email,
      phone: phone,
      address: address,
    );
    _cache.invalidateAll();
    return s;
  }

  Future<void> destroy(String id) async {
    await _remote.destroy(id);
    _cache.invalidateAll();
  }

  Future<List<SupplierProductData>> listProducts(String supplierId,
      {bool forceRefresh = false}) async {
    final key = 'supplier-products:$supplierId';
    if (!forceRefresh) {
      final cached = _cache.get<List<SupplierProductData>>(key);
      if (cached != null) return cached;
    }
    final fresh = await _remote.listProducts(supplierId);
    _cache.put(key, fresh);
    return fresh;
  }

  Future<SupplierProductData> attachProduct(
    String supplierId, {
    required String productId,
    String? supplierReference,
    int? packSize,
    double? price,
  }) async {
    final link = await _remote.attachProduct(
      supplierId,
      productId: productId,
      supplierReference: supplierReference,
      packSize: packSize,
      price: price,
    );
    _cache.invalidate('supplier-products:$supplierId');
    return link;
  }
}
