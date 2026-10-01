import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/env.dart';
import '../utils/pii_scrubber.dart';

class CrashReporter {
  bool get isEnabled => Env.sentryDsn.isNotEmpty;

  Future<void> init() async {
    if (!isEnabled) {
      if (kDebugMode) debugPrint('crash reporter: init skipped (empty DSN)');
      return;
    }
    await SentryFlutter.init((options) {
      options.dsn = Env.sentryDsn;
      options.environment = Env.environment;
      options.sendDefaultPii = false;
      options.beforeSend = (event, hint) => scrubEvent(event);
      options.beforeBreadcrumb = (breadcrumb, hint) =>
          scrubBreadcrumb(breadcrumb);
    });
  }

  void capture(Object error, StackTrace stack, {Map<String, Object?>? extras}) {
    if (kDebugMode) debugPrint('crash: ${error.runtimeType}');
    if (!isEnabled) return;
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stack,
        hint: Hint.withMap(extras ?? const {}),
      ),
    );
  }

  void breadcrumb(String message, {Map<String, Object?>? data}) {
    if (kDebugMode) debugPrint('breadcrumb: application event');
    if (!isEnabled) return;
    unawaited(Sentry.addBreadcrumb(Breadcrumb(message: message, data: data)));
  }

  @visibleForTesting
  SentryEvent? scrubEvent(SentryEvent event) {
    final raw = event.toJson();
    final safe = <String, dynamic>{
      for (final key in [
        'event_id',
        'timestamp',
        'platform',
        'level',
        'release',
        'environment',
        'dist',
      ])
        if (raw[key] != null) key: raw[key],
      if (event.message != null) 'message': {'formatted': '[REDACTED]'},
    };
    final exceptions = event.exceptions;
    if (exceptions != null) {
      safe['exception'] = {
        'values': exceptions.map((exception) {
          final source = exception.toJson();
          final stack = source['stacktrace'];
          return <String, dynamic>{
            'type':
                RegExp(
                  r'^[A-Za-z_][A-Za-z0-9_.]{0,100}$',
                ).hasMatch(exception.type ?? '')
                ? exception.type
                : 'Error',
            'value': '[REDACTED]',
            if (stack is Map && stack['frames'] is List)
              'stacktrace': {
                'frames': (stack['frames'] as List)
                    .whereType<Map>()
                    .map(
                      (frame) => {
                        if (frame['filename'] is String)
                          'filename': (frame['filename'] as String)
                              .replaceAll('\\', '/')
                              .split('/')
                              .last,
                        if (frame['lineno'] is num) 'lineno': frame['lineno'],
                        if (frame['colno'] is num) 'colno': frame['colno'],
                        if (frame['in_app'] is bool) 'in_app': frame['in_app'],
                      },
                    )
                    .toList(),
              },
          };
        }).toList(),
      };
    }
    if (event.breadcrumbs != null) {
      safe['breadcrumbs'] = event.breadcrumbs!
          .map((b) => scrubBreadcrumb(b)!.toJson())
          .toList();
    }
    return SentryEvent.fromJson(safe);
  }

  @visibleForTesting
  Breadcrumb? scrubBreadcrumb(Breadcrumb? breadcrumb) {
    if (breadcrumb == null) return null;
    return Breadcrumb(
      timestamp: breadcrumb.timestamp,
      category: 'app',
      message: breadcrumb.message == null ? null : '[REDACTED]',
      data: PiiScrubber.diagnostics(breadcrumb.data),
    );
  }
}
