import '../../../../core/network/cursor_page.dart';
import '../datasources/evidence_search_remote_datasource.dart';
import '../models/evidence_search_result_data.dart';

class EvidenceSearchRepository {
  final EvidenceSearchRemoteDatasource _remote;
  EvidenceSearchRepository(this._remote);

  Future<CursorPage<EvidenceSearchResultData>> search({
    String? cursor,
    String? patientReference,
    int? cycleNumber,
    String? batchNumber,
    DateTime? from,
    DateTime? to,
  }) {
    return _remote.search(
      cursor: cursor,
      patientReference: patientReference,
      cycleNumber: cycleNumber,
      batchNumber: batchNumber,
      from: from,
      to: to,
    );
  }
}
