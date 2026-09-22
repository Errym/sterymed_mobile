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
      options.beforeSend = (event, hint) => _scrubEvent(event);
      options.beforeBreadcrumb = (breadcrumb, hint) => _scrubBreadcrumb(breadcrumb);
    });
  }

  void capture(Object error, StackTrace stack, {Map<String, Object?>? extras}) {
    if (kDebugMode) debugPrint('crash: $error');
    if (!isEnabled) return;
    unawaited(Sentry.captureException(error, stackTrace: stack, hint: Hint.withMap(extras ?? const {})));
  }

  SentryEvent? _scrubEvent(SentryEvent event) {
    final message = event.message;
    if (message == null) return event;
    return event.copyWith(
      message: SentryMessage(PiiScrubber.scrub(message.formatted)),
    );
  }

  Breadcrumb? _scrubBreadcrumb(Breadcrumb? breadcrumb) {
    if (breadcrumb == null) return null;
    final message = breadcrumb.message;
    final data = breadcrumb.data;
    return breadcrumb.copyWith(
      message: message == null ? null : PiiScrubber.scrub(message),
      data: data?.map((key, value) => MapEntry(
            key,
            value is String ? PiiScrubber.scrub(value) : value,
          )),
    );
  }
}
