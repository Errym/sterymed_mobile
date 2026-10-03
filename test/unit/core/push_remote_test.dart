// A server without push support must produce a clear message, not "not found".

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/push/push_remote_datasource.dart';

Dio dioAnswering(int status) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    final response = Response(requestOptions: options, statusCode: status);
    if (status >= 400) {
      handler.reject(DioException(
        requestOptions: options,
        response: response,
        type: DioExceptionType.badResponse,
      ));
    } else {
      handler.resolve(response);
    }
  }));
  return dio;
}

void main() {
  const token = 'fcm-token-1234567890';

  test('registering succeeds when the server answers 204', () async {
    await PushRemoteDatasource(dioAnswering(204))
        .register(token: token, platform: 'android');
  });

  for (final status in [404, 405]) {
    test('a server answering $status says it has no notifications', () async {
      final remote = PushRemoteDatasource(dioAnswering(status));
      for (final call in [
        () => remote.register(token: token, platform: 'android'),
        () => remote.unregister(token),
      ]) {
        await expectLater(
          call(),
          throwsA(isA<ApiException>()
              .having((e) => e.code, 'code', 'push_unsupported')
              .having((e) => e.message, 'message', contains('pas encore les notifications'))),
        );
      }
    });
  }

  test('any other failure keeps its own mapped error', () async {
    await expectLater(
      PushRemoteDatasource(dioAnswering(500)).register(token: token, platform: 'android'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', isNot('push_unsupported'))),
    );
  });
}
