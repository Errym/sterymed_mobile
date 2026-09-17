import '../datasources/non_conformity_remote_datasource.dart';
import '../models/non_conformity_data.dart';

class NonConformityRepository {
  final NonConformityRemoteDatasource _remote;
  NonConformityRepository(this._remote);

  Future<List<NonConformityData>> list({String? status}) =>
      _remote.list(status: status);

  Future<void> resolve(String id, {required String resolution}) =>
      _remote.resolve(id, resolution: resolution);
}
