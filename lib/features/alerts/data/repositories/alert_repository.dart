import '../datasources/alert_remote_datasource.dart';
import '../models/alert_data.dart';

class AlertRepository {
  final AlertRemoteDatasource _remote;

  AlertRepository(this._remote);

  Future<List<AlertData>> getActiveAlerts() => _remote.fetchActive();

  Future<void> resolveAlert(String alertId) => _remote.resolve(alertId);
}
