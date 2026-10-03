import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/build_info.dart';

/// Compares dotted app versions ("1.4.0", "1.4.0+12"). Only the numeric
/// segments before any `+build` or `-tag` count.
abstract final class AppVersion {
  /// The numeric segments, or null when [raw] is not a version.
  static List<int>? parse(String? raw) {
    if (raw == null) return null;
    final core = raw.trim().split(RegExp(r'[+\-]')).first;
    if (core.isEmpty) return null;
    final parts = core.split('.');
    final out = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0) return null;
      out.add(n);
    }
    return out;
  }

  /// True when [current] is strictly older than [required]. An unreadable
  /// version on either side is never "older": the app must not lock itself out
  /// on a malformed header.
  static bool isOlder(String current, String required) {
    final a = parse(current);
    final b = parse(required);
    if (a == null || b == null) return false;
    final len = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x < y;
    }
    return false;
  }
}

/// Knows whether the server has said this build is too old to be used safely.
///
/// Contract (see docs/API_CONTRACT.md "Minimum app version"): the server may
/// send `X-Min-App-Version: 1.4.0` on any response, or answer `426` with the
/// same header when it refuses a request from an old build. Until the server
/// sends one, the gate never blocks.
class VersionGate extends ChangeNotifier {
  final String Function() _current;
  String? _required;

  VersionGate({String Function()? currentVersion})
      : _current = currentVersion ?? (() => BuildInfo.version);

  String get currentVersion => _current();
  String? get requiredVersion => _required;

  bool get blocked {
    final r = _required;
    return r != null && AppVersion.isOlder(_current(), r);
  }

  /// A version read from a response header. A readable value replaces the
  /// previous one in BOTH directions, so the server lowering its minimum
  /// unblocks the app.
  void observe(String? headerValue) {
    if (AppVersion.parse(headerValue) == null) return;
    final v = headerValue!.trim();
    if (v == _required) return;
    final wasBlocked = blocked;
    _required = v;
    if (wasBlocked != blocked) notifyListeners();
  }

  /// A `426 Upgrade Required` without a readable minimum still means "too
  /// old": block, naming no version.
  void markUpdateRequired(String? headerValue) {
    if (AppVersion.parse(headerValue) != null) {
      _required = headerValue!.trim();
    } else {
      // Anything above the current build counts as "newer than this one".
      _required = '999999.0.0';
    }
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _required = null;
    notifyListeners();
  }
}

/// Tells the server which build is calling, and listens for its answer.
class VersionGateInterceptor extends Interceptor {
  final VersionGate gate;
  VersionGateInterceptor(this.gate);

  static const requestHeader = 'X-App-Version';
  static const responseHeader = 'x-min-app-version';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[requestHeader] = gate.currentVersion;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    gate.observe(response.headers.value(responseHeader));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final res = err.response;
    if (res != null) {
      final header = res.headers.value(responseHeader);
      if (res.statusCode == 426) {
        gate.markUpdateRequired(header);
      } else {
        gate.observe(header);
      }
    }
    handler.next(err);
  }
}
