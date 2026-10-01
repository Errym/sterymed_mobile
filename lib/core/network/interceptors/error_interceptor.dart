import 'package:dio/dio.dart';

import '../../errors/error_mapper.dart';

class ErrorInterceptor extends Interceptor {
  /// Fired for a genuine `UNAUTHENTICATED` 401 from *any* endpoint, so the
  /// app can funnel it through one place (AuthBloc) regardless of which
  /// screen/repository triggered the request that got it — see
  /// `AuthSessionExpired`.
  final void Function()? onUnauthenticated;

  ErrorInterceptor({this.onUnauthenticated});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final apiException = ErrorMapper.fromDio(err);
    if (apiException.isUnauthenticated &&
        err.requestOptions.extra['skipAuthExpiry'] != true) {
      onUnauthenticated?.call();
    }
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: apiException,
        message: apiException.message,
      ),
    );
  }
}
