import 'dart:convert';

import 'package:dio/dio.dart';

import '../../utils/idempotency_key.dart';

/// Every POST mutates state, so every POST carries an `Idempotency-Key`
/// (no path whitelist: a whitelist drifted twice and silently missed whole
/// resource families, see the 2026-09-27 audit).
///
/// A key is normally fresh per request. The exception is a *lost answer*:
/// when an identical request (same owner, path, query and body) ended with an
/// unknown outcome (timeout, dropped connection, 5xx, 429) the next identical
/// submit reuses that key, so a server that already committed replays its
/// answer instead of creating a duplicate. A definitive answer (success or a
/// deterministic 4xx) forgets the key, so a deliberate second creation is never
/// swallowed as a "replay".
///
/// The memory is per app run. Queued operations (stock, usage, receipts,
/// cycle transitions) do not rely on this: their key is persisted with them.
class IdempotencyInterceptor extends Interceptor {
  static const _maxEntries = 64;
  static const _lifetime = Duration(minutes: 30);
  static const _fingerprintKey = 'idempotency_fingerprint';

  final String? Function()? _owner;
  final DateTime Function() _now;
  final Map<String, _Remembered> _unresolved = {};

  IdempotencyInterceptor({this._owner, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  String? _fingerprint(RequestOptions options) {
    final data = options.data;
    if (data != null && data is! Map && data is! List && data is! String) {
      return null; // multipart/streams: never reuse
    }
    final body = data is String ? data : jsonEncode(data);
    return jsonEncode([
      _owner?.call(),
      options.method,
      options.path,
      options.queryParameters,
      body,
    ]);
  }

  void _forgetExpired() {
    final cutoff = _now().subtract(_lifetime);
    _unresolved.removeWhere((_, value) => value.at.isBefore(cutoff));
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method == 'POST' &&
        !options.headers.containsKey('Idempotency-Key')) {
      final fingerprint = _fingerprint(options);
      _forgetExpired();
      final reused = fingerprint == null ? null : _unresolved[fingerprint];
      options.headers['Idempotency-Key'] =
          reused?.key ?? generateIdempotencyKey();
      if (fingerprint != null) options.extra[_fingerprintKey] = fingerprint;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _settle(response.requestOptions);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    final definitive =
        status != null && status < 500 && status != 429 && status != 408;
    if (definitive) {
      _settle(err.requestOptions);
    } else {
      _remember(err.requestOptions);
    }
    handler.next(err);
  }

  void _settle(RequestOptions options) {
    final fingerprint = options.extra[_fingerprintKey] as String?;
    if (fingerprint != null) _unresolved.remove(fingerprint);
  }

  void _remember(RequestOptions options) {
    final fingerprint = options.extra[_fingerprintKey] as String?;
    final key = options.headers['Idempotency-Key'] as String?;
    if (fingerprint == null || key == null) return;
    if (_unresolved.length >= _maxEntries &&
        !_unresolved.containsKey(fingerprint)) {
      _unresolved.remove(_unresolved.keys.first);
    }
    _unresolved[fingerprint] = _Remembered(key, _now());
  }
}

class _Remembered {
  final String key;
  final DateTime at;
  const _Remembered(this.key, this.at);
}
