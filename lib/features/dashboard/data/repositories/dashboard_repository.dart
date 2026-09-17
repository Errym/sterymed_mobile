import '../datasources/dashboard_remote_datasource.dart';
import '../models/dashboard_data.dart';

class DashboardRepository {
  final DashboardRemoteDatasource _remote;
  DashboardRepository(this._remote);
  Future<DashboardData> fetch() => _remote.fetch();
}
