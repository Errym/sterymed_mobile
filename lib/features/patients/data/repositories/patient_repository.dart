import '../../../../core/cache/cache.dart';
import '../../../../core/utils/logger.dart';
import '../datasources/patient_remote_datasource.dart';
import '../local/patient_local_cache.dart';
import '../models/patient_create_request.dart';
import '../models/patient_data.dart';

class PatientRepository {
  final PatientRemoteDatasource _remote;
  final AppCache _cache;
  final PatientLocalCache _local;

  PatientRepository(this._remote, this._cache, this._local);

  Future<List<PatientData>> search(
    String query, {
    bool forceRefresh = false,
  }) async {
    // We don't cache the API list here — the local patient cache handles
    // the display values. Always hit the API so we reflect server changes.
    final fromApi = await _remote.search(query);
    // Merge with the local cache so name/phone/email show up.
    return _local.merge(fromApi);
  }

  Future<PatientData> create(PatientCreateRequest req) async {
    final created = await _remote.create(req);
    // The API only returns { id, reference }. Save the full record locally
    // so the name and other fields survive.
    final full = PatientData(
      id: created.id,
      firstName: req.firstName,
      lastName: req.lastName,
      reference: created.reference ?? req.reference,
      birthDate: req.birthDate,
      phone: req.phone,
      email: req.email,
    );
    await _local.save(full);
    _cache.invalidateAll();
    return full;
  }

  Future<PatientData> show(String id) async {
    // Prefer the local cache — it has the real values.
    final cached = await _local.get(id);
    if (cached != null) return cached;
    // Fall back to the API (which only has id + reference).
    return _remote.show(id);
  }

  Future<void> destroy(String id) async {
    await _remote.destroy(id);
    await _local.remove(id);
    _cache.invalidateAll();
  }

  /// Edit = delete + recreate (backend has no PATCH /v1/patients).
  /// We keep the local cache consistent through both steps.
  Future<PatientData> update({
    required String id,
    required PatientCreateRequest req,
  }) async {
    AppLogger.d('PatientRepository.update: delete + recreate for $id');
    await _remote.destroy(id);
    await _local.remove(id);
    final created = await _remote.create(req);
    final full = PatientData(
      id: created.id,
      firstName: req.firstName,
      lastName: req.lastName,
      reference: created.reference ?? req.reference,
      birthDate: req.birthDate,
      phone: req.phone,
      email: req.email,
    );
    await _local.save(full);
    _cache.invalidateAll();
    return full;
  }
}
