import '../datasources/device_remote_datasource.dart';
import '../models/device_data.dart';

class DeviceRepository {
  final DeviceRemoteDatasource _remote;
  DeviceRepository(this._remote);

  Future<List<DeviceData>> list() => _remote.list();
}
