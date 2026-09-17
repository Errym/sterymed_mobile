import '../../../../core/cache/cache.dart';
import '../datasources/batch_remote_datasource.dart';
import '../models/batch_data.dart';

class BatchRepository {
  final BatchRemoteDatasource _remote;
  final AppCache _cache;

  BatchRepository(this._remote, this._cache);

  Future<List<BatchData>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<BatchData>>('batches');
      if (cached != null) return cached;
    }
    final fresh = await _remote.list();
    _cache.put('batches', fresh);
    return fresh;
  }
}
