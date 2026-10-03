import 'package:dio/dio.dart';

import '../config/api_endpoints.dart';
import '../errors/error_mapper.dart';
import '../utils/idempotency_key.dart';

/// Tells the server which phone to notify for the signed-in member.
class PushRemoteDatasource {
  final Dio _dio;
  PushRemoteDatasource(this._dio);

  Future<void> register({
    required String token,
    required String platform,
    String? appVersion,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.pushTokens,
        data: {
          'token': token,
          'platform': platform,
          if (appVersion != null) 'app_version': appVersion,
        },
        options: Options(headers: {'Idempotency-Key': generateIdempotencyKey()}),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> unregister(String token) async {
    try {
      await _dio.delete(ApiEndpoints.pushTokens, data: {'token': token});
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
