// The 401 → login redirect chain, network-layer half. Any endpoint
// returning a real UNAUTHENTICATED 401 must fire `onUnauthenticated`
// exactly once, funneling into AuthBloc regardless of which
// screen/repository made the request (see auth_bloc_test.dart's
// AuthSessionExpired case for the other half, and
// go_router_refresh_stream_test.dart for how that state change reaches
// the router). Deliberately checks the negative cases too: a 401 with a
// *different* real code (login's own INVALID_CREDENTIALS is also a 401
// status but is not a session-expiry signal), and non-401 errors, must
// never fire it.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/network/interceptors/error_interceptor.dart';

void main() {
  late Dio dio;
  late int callCount;

  setUp(() {
    callCount = 0;
    dio = Dio();
    dio.interceptors.add(
      ErrorInterceptor(onUnauthenticated: () => callCount++),
    );
  });

  Future<void> respondWith(int status, {String? code}) async {
    dio.httpClientAdapter = _FixedResponseAdapter(status: status, code: code);
    try {
      await dio.get('/v1/anything');
    } on DioException {
      // Expected — ErrorInterceptor always rejects.
    }
  }

  test(
    'a deliberate real 401 UNAUTHENTICATED from any endpoint fires '
    'onUnauthenticated exactly once',
    () async {
      await respondWith(401, code: 'UNAUTHENTICATED');
      expect(callCount, 1);
    },
  );

  test(
    'a 401 with a different real code (e.g. login\'s own '
    'INVALID_CREDENTIALS) does not fire onUnauthenticated',
    () async {
      await respondWith(401, code: 'INVALID_CREDENTIALS');
      expect(callCount, 0);
    },
  );

  for (final status in [403, 404, 409, 422, 429, 500]) {
    test('a $status response does not fire onUnauthenticated', () async {
      await respondWith(status, code: 'SOME_OTHER_CODE');
      expect(callCount, 0);
    });
  }
}

/// Minimal fake transport returning a fixed status + real error envelope
/// without any real network I/O.
class _FixedResponseAdapter implements HttpClientAdapter {
  final int status;
  final String? code;

  _FixedResponseAdapter({required this.status, this.code});

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = '{"error":{"code":"${code ?? 'UNKNOWN'}","message":"x",'
        '"details":{},"request_id":"req-1"}}';
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
