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
}
