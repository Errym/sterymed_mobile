import '../datasources/site_remote_datasource.dart';
import '../models/site_data.dart';

class SiteRepository {
  final SiteRemoteDatasource _remote;
  SiteRepository(this._remote);
  Future<List<SiteData>> list() => _remote.list();
}
