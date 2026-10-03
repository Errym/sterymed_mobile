import '../../../../core/cache/cache.dart';
import '../../../../core/network/cursor_page.dart';
import '../datasources/alert_remote_datasource.dart';
import '../models/alert_data.dart';

class AlertRepository {
  final AlertRemoteDatasource _remote;
  final AppCache _cache;

  AlertRepository(this._remote, this._cache);

  /// [state] is `open` (default), `resolved`, or null for both; [type] is one
  /// of [AlertType]. Only the plain open list is cached: a filtered list is
  /// cheap to ask again and must never be served from another filter's slot.
  Future<CursorPage<AlertData>> getActiveAlerts({
    bool forceRefresh = false,
    String? type,
    String? state = 'open',
  }) async {
    final cacheable = type == null && state == 'open';
    if (cacheable && !forceRefresh) {
      final cached = _cache.get<CursorPage<AlertData>>('alerts');
      if (cached != null) return cached;
    }
    final fresh = await _remote.fetchActive(type: type, state: state);
    if (cacheable) _cache.put('alerts', fresh);
    return fresh;
  }

  /// Paginated fetches always hit the network — caching a "page" under a
  /// cursor-keyed slot isn't worth it for an infinite-scroll list.
  Future<CursorPage<AlertData>> loadMore(
    String cursor, {
    String? type,
    String? state = 'open',
  }) =>
      _remote.fetchActive(cursor: cursor, type: type, state: state);

  Future<void> resolveAlert(String alertId) async {
    await _remote.resolve(alertId);
    _cache.invalidate('alerts');
    _cache.invalidate('dashboard');
  }
}
