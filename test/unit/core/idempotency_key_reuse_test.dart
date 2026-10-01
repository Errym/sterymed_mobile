import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/network/interceptors/idempotency_interceptor.dart';

/// Replies with a scripted outcome per request and records the key it saw.
class _Script implements HttpClientAdapter {
  final keys = <String?>[];
  final outcomes = <Object>[]; // int status | DioExceptionType
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    keys.add(options.headers['Idempotency-Key'] as String?);
    final next = outcomes.isEmpty ? 201 : outcomes.removeAt(0);
    if (next is DioExceptionType) {
      throw DioException(requestOptions: options, type: next);
    }
    return ResponseBody.fromString(
      jsonEncode({'id': 'x'}),
      next as int,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Script script;
  late Dio dio;
  late DateTime clock;
  var owner = 'clinic-A/user-1';

  setUp(() {
    owner = 'clinic-A/user-1';
    clock = DateTime.utc(2026, 10, 1, 9);
    script = _Script();
    dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api'))
      ..httpClientAdapter = script
      ..interceptors.add(
        IdempotencyInterceptor(owner: () => owner, now: () => clock),
      );
  });

  Future<void> post(
    Map<String, dynamic> body, {
    String path = '/v1/suppliers',
  }) async {
    try {
      await dio.post<void>(path, data: body);
    } on DioException {
      // outcome is asserted through the keys the server saw
    }
  }

  test(
    'every POST carries a key, and different requests get different keys',
    () async {
      await post({'name': 'A'});
      await post({'name': 'B'});
      expect(script.keys.every((k) => k != null && k.isNotEmpty), isTrue);
      expect(script.keys[0], isNot(script.keys[1]));
    },
  );

  test(
    'a lost answer makes the identical re-submit reuse the same key',
    () async {
      script.outcomes.add(DioExceptionType.receiveTimeout);
      await post({'name': 'Fournisseur'});
      await post({'name': 'Fournisseur'});
      expect(script.keys[1], script.keys[0]);
    },
  );

  test('a 5xx or 429 also counts as an unknown outcome', () async {
    script.outcomes.addAll([503, 429]);
    await post({'name': 'A'});
    await post({'name': 'A'});
    await post({'name': 'A'});
    expect(script.keys.toSet(), hasLength(1));
  });

  test(
    'after a definitive success a deliberate second creation gets a new key',
    () async {
      script.outcomes.addAll([DioExceptionType.receiveTimeout, 201, 201]);
      await post({'name': 'A'}); // lost
      await post({'name': 'A'}); // replay with same key, answered 201
      await post({'name': 'A'}); // user really wants another one
      expect(script.keys[1], script.keys[0]);
      expect(script.keys[2], isNot(script.keys[0]));
    },
  );

  test('a deterministic 4xx forgets the key', () async {
    script.outcomes.addAll([DioExceptionType.connectionError, 422, 201]);
    await post({'name': 'A'});
    await post({'name': 'A'});
    await post({'name': 'A'});
    expect(script.keys[1], script.keys[0]);
    expect(script.keys[2], isNot(script.keys[1]));
  });

  test('a changed body, path or owner never reuses a key', () async {
    script.outcomes.addAll([
      DioExceptionType.receiveTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.receiveTimeout,
    ]);
    await post({'name': 'A'});
    await post({'name': 'B'}); // body
    await post({'name': 'A'}, path: '/v1/products'); // path
    owner = 'clinic-B/user-2';
    await post({'name': 'A'}); // owner
    expect(script.keys.toSet(), hasLength(4));
  });

  test('an unknown outcome is forgotten after its lifetime', () async {
    script.outcomes.add(DioExceptionType.receiveTimeout);
    await post({'name': 'A'});
    clock = clock.add(const Duration(minutes: 31));
    await post({'name': 'A'});
    expect(script.keys[1], isNot(script.keys[0]));
  });

  test('an explicit key (the durable queue) is never replaced', () async {
    await dio.post<void>(
      '/v1/stock-movements/issue',
      data: {'qty': 1},
      options: Options(headers: {'Idempotency-Key': 'queue-key'}),
    );
    expect(script.keys.single, 'queue-key');
  });
}
