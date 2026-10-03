import 'package:dio/dio.dart';

import '../config/api_endpoints.dart';
import '../errors/api_exception.dart';
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
      throw _unsupportedOr(e);
    }
  }

  /// A server that has no push registration route answers 404 or 405. Say so
  /// in words, instead of the generic "not found", so nobody thinks the phone
  /// or the account is at fault.
  Object _unsupportedOr(DioException e) {
    final status = e.response?.statusCode;
    if (status == 404 || status == 405) {
      return const ApiException(
        code: 'push_unsupported',
        message: 'Ce serveur ne propose pas encore les notifications. '
            "Les alertes restent visibles dans l'onglet Alertes.",
      );
    }
    return ErrorMapper.fromDio(e);
  }

  Future<void> unregister(String token) async {
    try {
      await _dio.delete(ApiEndpoints.pushTokens, data: {'token': token});
    } on DioException catch (e) {
      throw _unsupportedOr(e);
    }
  }
}
