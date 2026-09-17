import '../../../../core/cache/cache.dart';
import '../datasources/patient_remote_datasource.dart';
import '../models/patient_create_request.dart';
import '../models/patient_data.dart';

class PatientRepository {
  final PatientRemoteDatasource _remote;
  final AppCache _cache;

  PatientRepository(this._remote, this._cache);

  Future<List<PatientData>> search(String query, {bool forceRefresh = false}) async {
    if (!forceRefresh && query.trim().isEmpty) {
      final cached = _cache.get<List<PatientData>>('patients:all');
      if (cached != null) return cached;
    }
    final fresh = await _remote.search(query);
    if (query.trim().isEmpty) _cache.put('patients:all', fresh);
    return fresh;
  }

  Future<PatientData> create(PatientCreateRequest req) async {
    final p = await _remote.create(req);
    _cache.invalidateAll();
    return p;
  }

  Future<PatientData> show(String id) => _remote.show(id);

  Future<void> destroy(String id) async {
    await _remote.destroy(id);
    _cache.invalidateAll();
  }
}
