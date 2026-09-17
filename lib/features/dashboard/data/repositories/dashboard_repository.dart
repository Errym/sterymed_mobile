import '../../../../core/cache/cache.dart';
import '../datasources/dashboard_remote_datasource.dart';
import '../models/dashboard_data.dart';

class DashboardRepository {
  final DashboardRemoteDatasource _remote;
  final AppCache _cache;

  DashboardRepository(this._remote, this._cache);

  Future<DashboardData> fetch({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<DashboardData>('dashboard');
      if (cached != null) return cached;
    }
    final fresh = await _remote.fetch();
    _cache.put('dashboard', fresh);
    return fresh;
  }
}
