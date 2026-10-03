import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/network/cursor_page.dart';
import '../../../../core/utils/date_filter.dart';
import '../models/evidence_search_result_data.dart';

/// The filters of an evidence search as query parameters. The list and the
/// export both use it, so an export is exactly what the screen shows.
Map<String, dynamic> evidenceFilterQuery({
  String? patientReference,
  int? cycleNumber,
  String? batchNumber,
  DateTime? from,
  DateTime? to,
}) =>
    {
      if (patientReference != null && patientReference.isNotEmpty)
        'patient_reference': patientReference,
      if (cycleNumber != null) 'cycle_number': cycleNumber,
      if (batchNumber != null && batchNumber.isNotEmpty)
        'batch_number': batchNumber,
      if (from != null) 'from': fromParam(from),
      if (to != null) 'to': toParam(to),
    };

class EvidenceSearchRemoteDatasource {
  final Dio _dio;
  EvidenceSearchRemoteDatasource(this._dio);

  Future<CursorPage<EvidenceSearchResultData>> search({
    String? cursor,
    String? patientReference,
    int? cycleNumber,
    String? batchNumber,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.evidenceSearch,
        queryParameters: {
          if (cursor != null) 'cursor': cursor,
          ...evidenceFilterQuery(
            patientReference: patientReference,
            cycleNumber: cycleNumber,
            batchNumber: batchNumber,
            from: from,
            to: to,
          ),
          'limit': 20,
        },
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) {
        return const CursorPage(items: []);
      }
      final json = raw.cast<String, dynamic>();
      final items = (json['data'] as List)
          .whereType<Map>()
          .map((e) =>
              EvidenceSearchResultData.fromJson(e.cast<String, dynamic>()))
          .toList();
      return CursorPage(
        items: items,
        nextCursor: CursorPage.cursorFromMeta(json),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
