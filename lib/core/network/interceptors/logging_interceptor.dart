import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../utils/pii_scrubber.dart';

class LoggingInterceptor extends Interceptor {
  void _log(RequestOptions request, int? status) {
    if (kDebugMode) {
      debugPrint(
        'http: ${PiiScrubber.diagnostics({'method': request.method, 'status_code': status})}',
      );
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _log(options, null);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log(response.requestOptions, response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(err.requestOptions, err.response?.statusCode);
    handler.next(err);
  }
}
