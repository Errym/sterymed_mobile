import '../../../../core/cache/cache.dart';
import '../datasources/supplier_remote_datasource.dart';
import '../models/supplier_data.dart';

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
}
