import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../config/env.dart';
import '../storage/token_storage.dart';
import '../storage/session_store.dart';
import '../version/version_gate.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/idempotency_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

class DioClient {
  final Dio dio;

  DioClient(
    TokenStorage tokenStorage, {
    void Function()? onUnauthenticated,
    void Function()? onForbidden,
    SessionStore? session,
    VersionGate? versionGate,
  }) : dio = Dio(
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
      // Before everything: it must see the raw 426 / header, not a mapped error.
      if (versionGate != null) VersionGateInterceptor(versionGate),
      AuthInterceptor(tokenStorage, session: session),
      IdempotencyInterceptor(owner: () => session?.scopeKey),
      RetryInterceptor(dio),
      ErrorInterceptor(
        onUnauthenticated: onUnauthenticated,
        onForbidden: onForbidden,
      ),
      LoggingInterceptor(),
    ]);
  }
}
