import '../../../../core/cache/cache.dart';
import '../../../../core/network/cursor_page.dart';
import '../datasources/audit_remote_datasource.dart';
import '../models/audit_event_data.dart';

class AuditRepository {
  final AuditRemoteDatasource _remote;
  final AppCache _cache;

  AuditRepository(this._remote, this._cache);

  Future<CursorPage<AuditEventData>> list({
    String? cursor,
    String? action,
    String? actorId,
    String? subjectType,
    DateTime? from,
    DateTime? to,
    bool forceRefresh = false,
  }) async {
    final key = 'audit:${action ?? 'all'}:${actorId ?? '-'}:'
        '${subjectType ?? '-'}:${from?.toIso8601String() ?? '-'}:'
        '${to?.toIso8601String() ?? '-'}:${cursor ?? 'start'}';
    if (!forceRefresh) {
      final cached = _cache.get<CursorPage<AuditEventData>>(key);
      if (cached != null) return cached;
    }
    final fresh = await _remote.list(
      cursor: cursor,
      action: action,
      actorId: actorId,
      subjectType: subjectType,
      from: from,
      to: to,
    );
    _cache.put(key, fresh);
    return fresh;
  }
}
