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
      options.beforeSend = (event, hint) => scrubEvent(event);
      options.beforeBreadcrumb = (breadcrumb, hint) => scrubBreadcrumb(breadcrumb);
    });
  }

  void capture(Object error, StackTrace stack, {Map<String, Object?>? extras}) {
    if (kDebugMode) debugPrint('crash: $error');
    if (!isEnabled) return;
    unawaited(Sentry.captureException(error, stackTrace: stack, hint: Hint.withMap(extras ?? const {})));
  }

  void breadcrumb(String message, {Map<String, Object?>? data}) {
    if (kDebugMode) debugPrint('breadcrumb: $message');
    if (!isEnabled) return;
    unawaited(Sentry.addBreadcrumb(Breadcrumb(message: message, data: data)));
  }

  // `capture()` above passes the raw error object to `captureException`,
  // whose text ends up in `event.exceptions[].value` — a completely
  // separate field from `event.message` (which Sentry only populates for
  // `captureMessage`). The original version of this method only scrubbed
  // `.message`, so an ApiException whose real backend message happened to
  // quote a patient/practitioner id or similar would have reached Sentry
  // unscrubbed via `.exceptions` the moment anything called `capture()`.
  // Found and fixed during the Task 4.1 security audit — `capture()` has
  // zero call sites in lib/ today, so nothing has actually leaked yet, but
  // the beforeSend hook needs to be correct before the first call site is
  // added, not after. (`capture()`'s own `extras` param goes into `Hint`,
  // not `event.extra` — `Hint` is a local-only side channel for this
  // callback, never serialized to Sentry, so there's nothing to scrub
  // there; `event.extra` itself is deprecated by the SDK and unused here.)
  @visibleForTesting
  SentryEvent? scrubEvent(SentryEvent event) {
    final message = event.message;
    if (message != null) {
      event.message = SentryMessage(PiiScrubber.scrub(message.formatted));
    }
    final exceptions = event.exceptions;
    if (exceptions != null) {
      for (final exception in exceptions) {
        final value = exception.value;
        if (value != null) exception.value = PiiScrubber.scrub(value);
      }
    }
    return event;
  }

  @visibleForTesting
  Breadcrumb? scrubBreadcrumb(Breadcrumb? breadcrumb) {
    if (breadcrumb == null) return null;
    final message = breadcrumb.message;
    if (message != null) {
      breadcrumb.message = PiiScrubber.scrub(message);
    }
    final data = breadcrumb.data;
    if (data != null) {
      breadcrumb.data = data.map((key, value) => MapEntry(
            key,
            value is String ? PiiScrubber.scrub(value) : value,
          ));
    }
    return breadcrumb;
  }
}
