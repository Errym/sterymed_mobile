import 'package:dio/dio.dart';
import '../../storage/token_storage.dart';
import '../../storage/session_store.dart';
import '../../errors/api_exception.dart';

class AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;
  final SessionStore? _session;

  AuthInterceptor(this._tokenStorage, {this._session});

  bool _detached(RequestOptions options) =>
      options.extra['detachedRevocation'] == true;
  bool _public(RequestOptions options) =>
      options.path.startsWith('/v1/auth/') && !_detached(options) ||
      options.path == '/v1/tenants';
  bool _stale(RequestOptions options) =>
      _session != null &&
      !_detached(options) &&
      options.extra['session_generation'] != _session.generation;

  DioException _cancel(RequestOptions options) => DioException(
    requestOptions: options,
    type: DioExceptionType.cancel,
    error: const ApiException(code: 'cancelled', message: 'Session remplacée.'),
  );

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_detached(options)) {
      options.extra['skipAuthExpiry'] = true;
      handler.next(options);
      return;
    }
    options.extra.putIfAbsent('session_generation', () => _session?.generation);
    if (_public(options)) {
      options.headers.remove('Authorization');
      options.extra['skipAuthExpiry'] = true;
      handler.next(options);
      return;
    }
    final token = await _tokenStorage.read();
    if (_stale(options) ||
        (options.extra['operation_owner'] != null &&
            options.extra['operation_owner'] != _session?.scopeKey)) {
      handler.reject(_cancel(options));
      return;
    }
    if (_session != null &&
        !{'GET', 'HEAD', 'OPTIONS'}.contains(options.method) &&
        !_session.canSend) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: const ApiException(
            code: 'session_validation_required',
            message: 'Actualisez votre session avant cette action.',
          ),
        ),
      );
      return;
    }
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (_stale(response.requestOptions)) {
      handler.reject(_cancel(response.requestOptions));
    } else {
      handler.next(response);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(
      _stale(err.requestOptions) ? _cancel(err.requestOptions) : err,
    );
  }
}
