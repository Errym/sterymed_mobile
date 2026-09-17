import 'package:dio/dio.dart';

import '../../utils/idempotency_key.dart';

class IdempotencyInterceptor extends Interceptor {
  static const _queuablePaths = <String>[
    '/auth/',
    '/labels/',
    '/stock-movements/',
    '/cycles/',
    '/tenants',
    '/invitations',
    '/non-conformities/',
  ];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method == 'POST' &&
        _isQueuable(options.path) &&
        !options.headers.containsKey('Idempotency-Key')) {
      options.headers['Idempotency-Key'] = generateIdempotencyKey();
    }
    handler.next(options);
  }

  bool _isQueuable(String path) => _queuablePaths.any(path.contains);
}
