import 'package:dio/dio.dart';

class RetryInterceptor extends Interceptor {
  final Dio _dio;
  final int maxRetries;

  RetryInterceptor(this._dio, {this.maxRetries = 2});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra['retry_attempt'] as int?) ?? 0;
    final isRetryable =
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.receiveTimeout ||
        (err.response?.statusCode ?? 0) >= 500;

    if (isRetryable && attempt < maxRetries) {
      final nextAttempt = attempt + 1;
      err.requestOptions.extra['retry_attempt'] = nextAttempt;
      await Future<void>.delayed(Duration(milliseconds: 300 * nextAttempt));
      try {
        final response = await _dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (_) {
        // fall through to original error
      }
    }
    handler.next(err);
  }
}
