import '../../../../core/cache/cache.dart';
import '../datasources/alert_remote_datasource.dart';
import '../models/alert_data.dart';

class AlertRepository {
  final AlertRemoteDatasource _remote;
  final AppCache _cache;

  AlertRepository(this._remote, this._cache);

  Future<List<AlertData>> getActiveAlerts({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<AlertData>>('alerts');
      if (cached != null) return cached;
    }
    final fresh = await _remote.fetchActive();
    _cache.put('alerts', fresh);
    return fresh;
  }

  Future<void> resolveAlert(String alertId) async {
    await _remote.resolve(alertId);
    _cache.invalidate('alerts');
    _cache.invalidate('dashboard');
  }
}
