import 'package:dio/dio.dart';

import '../../utils/idempotency_key.dart';

/// Every POST mutates state (that's the whole point of POST vs GET), so
/// every POST gets an idempotency key — no path whitelist. A prior
/// path-substring whitelist here was found to have two classes of real
/// bug during a full audit (2026-09-27): several entries had a trailing
/// slash (`'/cycles/'`, `'/non-conformities/'`) that matched every
/// sub-action but missed the bare create POST to the resource's own list
/// path (`/v1/cycles`, `/v1/non-conformities`); and entire resource
/// categories with real create/action POSTs were missing from the list
/// entirely (alerts, patients, products, suppliers, purchase-orders,
/// prosthetic-cases, dlu-rules, laboratories, devices,
/// data-export-requests) — verified against every real `_dio.post(...)`
/// call site in `lib/features/**/data/datasources/`, not guessed. A
/// whitelist that must be remembered and kept in sync with every new
/// endpoint is exactly the kind of thing that silently drifts; this
/// removes the whole class of bug rather than patching the list again.
class IdempotencyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method == 'POST' &&
        !options.headers.containsKey('Idempotency-Key')) {
      options.headers['Idempotency-Key'] = generateIdempotencyKey();
    }
    handler.next(options);
  }
}
