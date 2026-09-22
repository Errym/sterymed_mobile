import '../../../../core/cache/cache.dart';
import '../../../../core/network/cursor_page.dart';
import '../datasources/alert_remote_datasource.dart';
import '../models/alert_data.dart';

class AlertRepository {
  final AlertRemoteDatasource _remote;
  final AppCache _cache;

  AlertRepository(this._remote, this._cache);

  Future<CursorPage<AlertData>> getActiveAlerts({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cache.get<CursorPage<AlertData>>('alerts');
      if (cached != null) return cached;
    }
    final fresh = await _remote.fetchActive();
    _cache.put('alerts', fresh);
    return fresh;
  }

  /// Paginated fetches always hit the network — caching a "page" under a
  /// cursor-keyed slot isn't worth it for an infinite-scroll list.
  Future<CursorPage<AlertData>> loadMore(String cursor) =>
      _remote.fetchActive(cursor: cursor);

  Future<void> resolveAlert(String alertId) async {
    await _remote.resolve(alertId);
    _cache.invalidate('alerts');
    _cache.invalidate('dashboard');
  }
}
