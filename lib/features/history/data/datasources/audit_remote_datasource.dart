import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../models/audit_event_data.dart';

class AuditRemoteDatasource {
  final Dio _dio;
  AuditRemoteDatasource(this._dio);

  Future<List<AuditEventData>> list({
    String? cursor,
    String? action,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.auditEvents,
        queryParameters: {
          if (cursor != null) 'cursor': cursor,
          if (action != null && action.isNotEmpty) 'filter[action]': action,
          'per_page': 30,
        },
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => AuditEventData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
