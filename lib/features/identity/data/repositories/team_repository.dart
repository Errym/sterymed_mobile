import '../datasources/team_remote_datasource.dart';
import '../models/team_member_data.dart';

class TeamRepository {
  final TeamRemoteDatasource _remote;
  TeamRepository(this._remote);

  Future<List<TeamMemberData>> list() => _remote.list();
  Future<void> invite({required String email, required String role}) =>
      _remote.invite(email: email, role: role);
  Future<void> disable(String tenantUserId) => _remote.disable(tenantUserId);
}
