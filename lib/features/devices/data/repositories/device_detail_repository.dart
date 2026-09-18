import '../../../../core/cache/cache.dart';
import '../datasources/device_detail_datasource.dart';
import '../models/device_detail.dart';

class DeviceDetailRepository {
  final DeviceDetailDatasource _remote;
  final AppCache _cache;

  DeviceDetailRepository(this._remote, this._cache);

  Future<List<DeviceDetail>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<DeviceDetail>>('devices');
      if (cached != null) return cached;
    }
    final fresh = await _remote.list();
    _cache.put('devices', fresh);
    return fresh;
  }

  Future<DeviceDetail> show(String id) => _remote.show(id);

  Future<DeviceDetail> update({
    required String id,
    String? name,
    String? model,
    String? serialNumber,
    String? manufacturer,
    String? status,
    String? notes,
  }) async {
    final d = await _remote.update(
      id: id,
      name: name,
      model: model,
      serialNumber: serialNumber,
      manufacturer: manufacturer,
      status: status,
      notes: notes,
    );
    _cache.invalidateAll();
    return d;
  }

  Future<void> destroy(String id) async {
    await _remote.destroy(id);
    _cache.invalidateAll();
  }
}
