import '../../../../core/cache/cache.dart';
import '../datasources/site_remote_datasource.dart';
import '../models/site_data.dart';

class SiteRepository {
  final SiteRemoteDatasource _remote;
  final AppCache _cache;

  SiteRepository(this._remote, this._cache);

  Future<List<SiteData>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<SiteData>>('sites');
      if (cached != null) return cached;
    }
    final fresh = await _remote.list();
    _cache.put('sites', fresh);
    return fresh;
  }
}
