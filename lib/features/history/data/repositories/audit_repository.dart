import '../../../../core/cache/cache.dart';
import '../datasources/audit_remote_datasource.dart';
import '../models/audit_event_data.dart';

class AuditRepository {
  final AuditRemoteDatasource _remote;
  final AppCache _cache;

  AuditRepository(this._remote, this._cache);

  Future<List<AuditEventData>> list({
    String? cursor,
    String? action,
    bool forceRefresh = false,
  }) async {
    final key = 'audit:${action ?? 'all'}:${cursor ?? 'start'}';
    if (!forceRefresh) {
      final cached = _cache.get<List<AuditEventData>>(key);
      if (cached != null) return cached;
    }
    final fresh = await _remote.list(cursor: cursor, action: action);
    _cache.put(key, fresh);
    return fresh;
  }
}
