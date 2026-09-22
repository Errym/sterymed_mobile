import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/network/cursor_page.dart';
import '../models/audit_event_data.dart';

class AuditRemoteDatasource {
  final Dio _dio;
  AuditRemoteDatasource(this._dio);

  Future<CursorPage<AuditEventData>> list({
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
      if (raw is! Map || raw['data'] is! List) {
        return const CursorPage(items: []);
      }
      final json = raw.cast<String, dynamic>();
      final items = (json['data'] as List)
          .whereType<Map>()
          .map((e) => AuditEventData.fromJson(e.cast<String, dynamic>()))
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
