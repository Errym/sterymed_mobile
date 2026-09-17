import '../../../../core/cache/cache.dart';
import '../datasources/product_remote_datasource.dart';
import '../models/product_data.dart';

class ProductRepository {
  final ProductRemoteDatasource _remote;
  final AppCache _cache;

  ProductRepository(this._remote, this._cache);

  Future<List<ProductData>> list({String? search, bool forceRefresh = false}) async {
    final key = 'products:${search ?? ''}';
    if (!forceRefresh) {
      final cached = _cache.get<List<ProductData>>(key);
      if (cached != null) return cached;
    }
    final fresh = await _remote.list(search: search);
    _cache.put(key, fresh);
    return fresh;
  }

  Future<ProductData> create(ProductCreateRequest req) async {
    final p = await _remote.create(req);
    _cache.invalidateAll();
    return p;
  }

  Future<ProductData> update(String id, ProductCreateRequest req) async {
    final p = await _remote.update(id, req);
    _cache.invalidateAll();
    return p;
  }

  Future<void> destroy(String id) async {
    await _remote.destroy(id);
    _cache.invalidateAll();
  }
}
