import '../../../../core/cache/cache.dart';
import '../datasources/device_remote_datasource.dart';
import '../models/device_data.dart';

class DeviceRepository {
  final DeviceRemoteDatasource _remote;
  final AppCache _cache;

  DeviceRepository(this._remote, this._cache);

  Future<List<DeviceData>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<DeviceData>>('devices');
      if (cached != null) return cached;
    }
    final fresh = await _remote.list();
    _cache.put('devices', fresh);
    return fresh;
  }

  Future<DeviceData> create({
    required String siteId,
    required String name,
    required String serialNumber,
    required String kind,
    String? manufacturer,
    String? model,
    String? notes,
  }) async {
    final d = await _remote.create(
      siteId: siteId,
      name: name,
      serialNumber: serialNumber,
      kind: kind,
      manufacturer: manufacturer,
      model: model,
      notes: notes,
    );
    _cache.invalidateAll();
    return d;
  }
}
