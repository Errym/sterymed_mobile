import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/alert_data.dart';

class AlertRemoteDatasource {
  final Dio _dio;

  AlertRemoteDatasource(this._dio);

  /// GET /v1/alerts
  /// Returns active (unresolved) alerts, newest first.
  Future<List<AlertData>> fetchActive() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.alerts,
        queryParameters: {'resolved': false, 'per_page': 50},
      );
      final list = (response.data['data'] as List)
          .map((e) => AlertData.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      return list;
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  /// POST /v1/alerts/{id}/resolve
  /// Idempotency-Key is mandatory on every POST per the backend contract.
  Future<void> resolve(String alertId) async {
    try {
      await _dio.post(
        ApiEndpoints.alertResolve(alertId),
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
