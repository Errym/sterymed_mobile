// Task: "verify idempotency keys are attached to every POST that mutates
// state." A full audit against every real `_dio.post(...)` call site in
// lib/features/**/data/datasources/ found the interceptor's previous
// path-substring whitelist had two real bugs: several entries had a
// trailing slash (`/cycles/`, `/non-conformities/`) that matched every
// sub-action but missed the bare create POST to the resource's own list
// path; and entire resource categories with real create/action POSTs
// (alerts, patients, products, suppliers, purchase-orders,
// prosthetic-cases, dlu-rules, laboratories, devices,
// data-export-requests) were missing from the list entirely. Fixed by
// removing the whitelist — every POST mutates state, so every POST gets
// a key now. This test drives a real `Dio` instance (not a hand-rolled
// fake) through the actual interceptor, capturing the outgoing headers
// via a second interceptor placed right after it, then short-circuits
// before any real network call.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/network/interceptors/idempotency_interceptor.dart';

void main() {
  late Dio dio;
  late RequestOptions? captured;

  setUp(() {
    captured = null;
    dio = Dio();
    dio.interceptors.add(IdempotencyInterceptor());
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          // Short-circuits the chain before any real network I/O — this
          // test only cares what the request looked like leaving the
          // interceptor, not what a server would say back.
          handler.reject(
            DioException(requestOptions: options, message: 'short-circuit'),
          );
        },
      ),
    );
  });

  Future<void> post(String path) async {
    try {
      await dio.post(path);
    } on DioException {
      // Expected — the capturing interceptor always rejects.
    }
  }

  group('every real mutating POST call site gets an Idempotency-Key', () {
    // One representative path per resource category found in the full
    // `_dio.post(...)` audit — each of these previously fell through the
    // old whitelist for one of the two reasons in the file header above.
    const realMutatingPostPaths = [
      '/v1/auth/login',
      '/v1/tenants',
      '/v1/alerts/alert-1/resolve',
      '/v1/labels/label-1/usage',
      '/v1/cycles',
      '/v1/cycles/cycle-1/start',
      '/v1/dlu-rules',
      '/v1/invitations',
      '/v1/laboratories',
      '/v1/non-conformities',
      '/v1/non-conformities/nc-1/resolve',
      '/v1/patients',
      '/v1/products',
      '/v1/prosthetic-cases',
      '/v1/prosthetic-cases/case-1/status',
      '/v1/purchase-orders',
      '/v1/purchase-orders/po-1/receipts',
      '/v1/stock-movements/issue',
      '/v1/suppliers',
      '/v1/devices',
      '/v1/data-export-requests',
    ];

    for (final path in realMutatingPostPaths) {
      test(path, () async {
        await post(path);
        expect(
          captured?.headers.containsKey('Idempotency-Key'),
          isTrue,
          reason: '$path is a real POST call site with no Idempotency-Key',
        );
      });
    }
  });

  test('a GET request never gets an Idempotency-Key (it would be meaningless '
      'on a non-mutating request)', () async {
    try {
      await dio.get('/v1/cycles');
    } on DioException {
      // Expected.
    }
    expect(captured?.headers.containsKey('Idempotency-Key'), isFalse);
  });

  test('does not overwrite a caller-supplied Idempotency-Key', () async {
    try {
      await dio.post(
        '/v1/cycles',
        options: Options(headers: {'Idempotency-Key': 'caller-supplied'}),
      );
    } on DioException {
      // Expected.
    }
    expect(captured?.headers['Idempotency-Key'], 'caller-supplied');
  });
}
