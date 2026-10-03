import 'package:dio/dio.dart';

import '../../errors/error_mapper.dart';

class ErrorInterceptor extends Interceptor {
  /// Fired for a genuine `UNAUTHENTICATED` 401 from *any* endpoint, so the
  /// app can funnel it through one place (AuthBloc) regardless of which
  /// screen/repository triggered the request that got it — see
  /// `AuthSessionExpired`.
  final void Function()? onUnauthenticated;

  /// Fired for a `FORBIDDEN` 403: the server may have changed this user's
  /// role since the permissions were last read, so the app re-reads them
  /// instead of offering the same refused action for up to 15 minutes.
  final void Function()? onForbidden;

  ErrorInterceptor({this.onUnauthenticated, this.onForbidden});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final apiException = ErrorMapper.fromDio(err);
    if (apiException.isUnauthenticated &&
        err.requestOptions.extra['skipAuthExpiry'] != true) {
      onUnauthenticated?.call();
    }
    if (apiException.isForbidden) onForbidden?.call();
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
