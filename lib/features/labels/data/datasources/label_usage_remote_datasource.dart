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

  Future<List<LabelUsageData>> fetchHistory(String labelId) async {
    try {
      final response = await _dio.get(ApiEndpoints.labelUsage(labelId));
      final list = (response.data as List)
          .map((e) =>
              LabelUsageData.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      return list;
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
