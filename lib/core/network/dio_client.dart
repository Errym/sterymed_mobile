import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../config/env.dart';
import '../storage/token_storage.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/idempotency_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

class DioClient {
  final Dio dio;

  DioClient(TokenStorage tokenStorage)
    : dio = Dio(
        BaseOptions(
          baseUrl: Env.apiBaseUrl,
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
          sendTimeout: AppConfig.sendTimeout,
          headers: {'Accept': 'application/json'},
          contentType: 'application/json',
        ),
      ) {
    dio.interceptors.addAll([
      AuthInterceptor(tokenStorage),
      IdempotencyInterceptor(),
      RetryInterceptor(dio),
      ErrorInterceptor(),
      LoggingInterceptor(),
    ]);
  }
}
