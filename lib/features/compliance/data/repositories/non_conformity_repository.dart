import '../../../../core/cache/cache.dart';
import '../datasources/non_conformity_remote_datasource.dart';
import '../models/non_conformity_data.dart';

class NonConformityRepository {
  final NonConformityRemoteDatasource _remote;
  final AppCache _cache;

  NonConformityRepository(this._remote, this._cache);

  Future<List<NonConformityData>> list({
    String? status,
    bool forceRefresh = false,
  }) async {
    final key = 'non_conformities:${status ?? 'all'}';
    if (!forceRefresh) {
      final cached = _cache.get<List<NonConformityData>>(key);
      if (cached != null) return cached;
    }
    final fresh = await _remote.list(status: status);
    _cache.put(key, fresh);
    return fresh;
  }

  Future<NonConformityData> create({
    required String subjectType,
    required String subjectId,
    required String description,
  }) async {
    final nc = await _remote.create(
      subjectType: subjectType,
      subjectId: subjectId,
      description: description,
    );
    _cache.invalidateAll();
    return nc;
  }

  Future<void> resolve(String id, {required String resolution}) async {
    await _remote.resolve(id, resolution: resolution);
    _cache.invalidateAll();
  }
}
