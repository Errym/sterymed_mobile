import '../../../../core/cache/cache.dart';
import '../datasources/team_remote_datasource.dart';
import '../models/team_member_data.dart';

class TeamRepository {
  final TeamRemoteDatasource _remote;
  final AppCache _cache;

  TeamRepository(this._remote, this._cache);

  Future<List<TeamMemberData>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<TeamMemberData>>('team');
      if (cached != null) return cached;
    }
    final fresh = await _remote.list();
    _cache.put('team', fresh);
    return fresh;
  }

  Future<void> invite({required String email, required String role}) async {
    await _remote.invite(email: email, role: role);
    _cache.invalidate('team');
  }

  Future<void> disable(String tenantUserId) async {
    await _remote.disable(tenantUserId);
    _cache.invalidate('team');
  }
}
