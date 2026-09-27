import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/network/cursor_page.dart';
import '../models/evidence_search_result_data.dart';

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
          if (patientReference != null && patientReference.isNotEmpty)
            'patient_reference': patientReference,
          if (cycleNumber != null) 'cycle_number': cycleNumber,
          if (batchNumber != null && batchNumber.isNotEmpty)
            'batch_number': batchNumber,
          if (from != null) 'from': from.toIso8601String(),
          if (to != null) 'to': to.toIso8601String(),
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
