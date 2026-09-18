import '../../../../core/cache/cache.dart';
import '../../../../core/utils/logger.dart';
import '../datasources/patient_remote_datasource.dart';
import '../models/patient_create_request.dart';
import '../models/patient_data.dart';

class PatientRepository {
  final PatientRemoteDatasource _remote;
  final AppCache _cache;

  PatientRepository(this._remote, this._cache);

  Future<List<PatientData>> search(
    String query, {
    bool forceRefresh = false,
  }) async {
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

  /// Edit is implemented as delete + recreate because the backend has no
  /// PATCH /v1/patients/{id} endpoint (verified in docs/backend_routes.json).
  ///
  /// The old row is deleted and a new one is created with the new values.
  /// Downside: the id changes. Any historical records referencing the old
  /// id will point to a deleted patient. That is acceptable for the pilot
  /// because patients are only referenced by label-usage events, and the
  /// user is explicitly warned before confirming the edit.
  Future<PatientData> update({
    required String id,
    required PatientCreateRequest req,
  }) async {
    AppLogger.d('PatientRepository.update: delete + recreate for $id');
    await _remote.destroy(id);
    final created = await _remote.create(req);
    _cache.invalidateAll();
    return created;
  }
}
