import 'package:dio/dio.dart';

import '../../utils/idempotency_key.dart';

class IdempotencyInterceptor extends Interceptor {
  /// Every POST to these namespaces gets an `Idempotency-Key` header.
  /// The backend's `EnsureIdempotency` middleware rejects POSTs without one,
  /// so the list must cover every POST path we hit.
  static const _queuablePaths = <String>[
    '/auth/',
    '/labels/',
    '/stock-movements/',
    '/purchase-orders/',
    '/cycles/',
    '/prosthetic-cases/',
    '/tenants',
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

  bool _isQueuable(String path) {
    return _queuablePaths.any(path.contains);
  }
}
