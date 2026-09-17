import '../../../../core/cache/cache.dart';
import '../datasources/export_remote_datasource.dart';
import '../models/export_request_data.dart';

class ExportRepository {
  final ExportRemoteDatasource _remote;
  final AppCache _cache;

  ExportRepository(this._remote, this._cache);

  Future<List<ExportRequestData>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<ExportRequestData>>('data_exports');
      if (cached != null) return cached;
    }
    final fresh = await _remote.list();
    _cache.put('data_exports', fresh);
    return fresh;
  }

  Future<ExportRequestData> request() async {
    final r = await _remote.request();
    _cache.invalidate('data_exports');
    return r;
  }

  Future<String> downloadUrl(String id) => _remote.downloadUrl(id);
}
