// Task 4.1 (security audit) — "Verify with the PII scrubber tests + a new
// Sentry-beforeSend test." test/unit/core/pii_scrubber_test.dart already
// covers PiiScrubber.scrub's regex patterns in isolation; this file covers
// the actual Sentry integration point instead: CrashReporter.scrubEvent /
// scrubBreadcrumb, the functions wired to options.beforeSend /
// options.beforeBreadcrumb.
//
// Real gap found and fixed while writing this test: scrubEvent previously
// only scrubbed `event.message`, which Sentry only populates for
// `captureMessage`. CrashReporter.capture() actually calls
// `Sentry.captureException`, whose text lands in `event.exceptions[].value`
// — a field the old scrubEvent never touched. See the doc comment on
// scrubEvent in lib/core/crash/crash_reporter.dart for the full writeup.
// capture() has zero call sites in lib/ today, so nothing has leaked in
// production yet — this closes the gap before the first call site exists.

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:steriymed_mobile/core/crash/crash_reporter.dart';

void main() {
  late CrashReporter reporter;

  setUp(() {
    reporter = CrashReporter();
  });

  group('CrashReporter.scrubEvent (beforeSend)', () {
    test('scrubs event.message', () {
      final event = SentryEvent(
        message: SentryMessage('user token: {"token":"abc123"}'),
      );

      final out = reporter.scrubEvent(event);

      expect(out!.message!.formatted, isNot(contains('abc123')));
      expect(out.message!.formatted, contains('[REDACTED]'));
    });

    test(
      'scrubs event.exceptions[].value — the field captureException() '
      'actually populates, which the old implementation never touched',
      () {
        final event = SentryEvent(
          exceptions: [
            SentryException(
              type: 'ApiException',
              value: 'ApiException(code: conflict, '
                  'message: {"patient_id":"11111111-1111-1111-1111-111111111111"} '
                  'already has an open cycle, status: 409, requestId: req-1)',
            ),
          ],
        );

        final out = reporter.scrubEvent(event);

        final scrubbedValue = out!.exceptions!.single.value!;
        expect(scrubbedValue, isNot(contains('11111111-1111-1111-1111-111111111111')));
        expect(scrubbedValue, contains('[REDACTED]'));
      },
    );

    test('a clean event with no message/exceptions passes through unchanged', () {
      final event = SentryEvent();

      final out = reporter.scrubEvent(event);

      expect(out, isNotNull);
      expect(out!.message, isNull);
      expect(out.exceptions, isNull);
    });
  });

  group('CrashReporter.scrubBreadcrumb', () {
    test('scrubs breadcrumb.message', () {
      final out = reporter.scrubBreadcrumb(
        Breadcrumb(message: '{"password":"hunter2"}'),
      );

      expect(out!.message, isNot(contains('hunter2')));
    });

    test('scrubs string values in breadcrumb.data, leaves non-strings alone', () {
      final out = reporter.scrubBreadcrumb(
        Breadcrumb(data: {
          'tenantId': '{"token":"abc"}',
          'count': 5,
        }),
      );

      expect(out!.data!['tenantId'], isNot(contains('abc')));
      expect(out.data!['count'], 5);
    });

    test('a null breadcrumb passes through as null (does not throw)', () {
      expect(reporter.scrubBreadcrumb(null), isNull);
    });
  });
}
