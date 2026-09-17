import '../datasources/audit_remote_datasource.dart';
import '../models/audit_event_data.dart';

class AuditRepository {
  final AuditRemoteDatasource _remote;
  AuditRepository(this._remote);

  Future<List<AuditEventData>> list({String? cursor, String? action}) =>
      _remote.list(cursor: cursor, action: action);
}
