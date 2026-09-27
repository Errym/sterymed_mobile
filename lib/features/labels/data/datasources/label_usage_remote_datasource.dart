import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/label_usage_data.dart';

class LabelUsageRemoteDatasource {
  final Dio _dio;
  LabelUsageRemoteDatasource(this._dio);

  Future<LabelUsageData> recordUsage({
    required String labelId,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.labelUsage(labelId),
        data: payload,
        options: Options(
          headers: {
            'Idempotency-Key': idempotencyKey ?? generateIdempotencyKey(),
          },
        ),
      );
      return LabelUsageData.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  /// A label is used at most once — `GET .../usage` returns a single
  /// object (404 if it was never used), not a list. Wrapped in a 0-or-1
  /// list here so the caller's "history" shape doesn't have to change.
  Future<List<LabelUsageData>> fetchHistory(String labelId) async {
    try {
      final response = await _dio.get(ApiEndpoints.labelUsage(labelId));
      final data = response.data;
      if (data is! Map) return const [];
      return [LabelUsageData.fromJson(data.cast<String, dynamic>())];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const [];
      throw ErrorMapper.fromDio(e);
    }
  }
}
