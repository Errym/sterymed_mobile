import '../../../../core/cache/cache.dart';
import '../datasources/patient_remote_datasource.dart';
import '../models/patient_data.dart';

class PatientRepository {
  final PatientRemoteDatasource _remote;
  final AppCache _cache;

  PatientRepository(this._remote, this._cache);

  Future<List<PatientData>> search(
    String query, {
    bool forceRefresh = false,
  }) => _remote.search(query);

  /// Creates a new anonymous patient record — nothing to input, the
  /// backend generates the reference.
  Future<PatientData> create() async {
    final created = await _remote.create();
    _cache.invalidateAll();
    return created;
  }

  Future<PatientData> show(String id) => _remote.show(id);

  Future<void> destroy(String id) async {
    await _remote.destroy(id);
    _cache.invalidateAll();
  }
}
