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
      if (cached != null && cached.isNotEmpty) return cached;
    }
    final fresh = await _remote.list();
    if (fresh.isNotEmpty) {
      _cache.put('sites', fresh);
    } else {
      _cache.invalidate('sites');
    }
    return fresh;
  }

  Future<SiteData> create({
    required String name,
    String? addressLine1,
    String? city,
    bool isPrimary = false,
  }) async {
    final s = await _remote.create(
      name: name,
      addressLine1: addressLine1,
      city: city,
      isPrimary: isPrimary,
    );
    _cache.invalidate('sites');
    _cache.invalidateAll();
    return s;
  }
}
