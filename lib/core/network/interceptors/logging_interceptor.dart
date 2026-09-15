import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../utils/pii_scrubber.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('→ ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '← ${response.statusCode} ${response.requestOptions.uri}\n'
        '${PiiScrubber.scrub(response.data.toString())}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '✗ ${err.response?.statusCode} ${err.requestOptions.uri}\n'
        '${PiiScrubber.scrub(err.message ?? '')}',
      );
    }
    handler.next(err);
  }
}
