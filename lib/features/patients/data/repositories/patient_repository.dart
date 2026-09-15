import '../datasources/patient_remote_datasource.dart';
import '../models/patient_data.dart';

class PatientRepository {
  final PatientRemoteDatasource _remote;
  PatientRepository(this._remote);

  Future<List<PatientData>> search(String query) => _remote.search(query);
}
