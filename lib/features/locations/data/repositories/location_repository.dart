import '../../../../core/cache/cache.dart';
import '../datasources/location_remote_datasource.dart';
import '../models/location_data.dart';

class LocationRepository {
  final LocationRemoteDatasource _remote;
  final AppCache _cache;

  LocationRepository(this._remote, this._cache);

  Future<List<LocationData>> listForSite(String siteId,
      {bool forceRefresh = false}) async {
    final key = 'locations:$siteId';
    if (!forceRefresh) {
      final cached = _cache.get<List<LocationData>>(key);
      if (cached != null) return cached;
    }
    final fresh = await _remote.listForSite(siteId);
    _cache.put(key, fresh);
    return fresh;
  }
}
