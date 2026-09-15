import '../datasources/label_remote_datasource.dart';
import '../models/label_scan_result.dart';

class LabelRepository {
  final LabelRemoteDatasource _remote;
  LabelRepository(this._remote);

  Future<LabelScanResult> getByCode(String code) => _remote.fetchByCode(code);
}
