import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/utils/pii_scrubber.dart';

void main() {
  group('PiiScrubber.scrub', () {
    test('redacts token', () {
      final out = PiiScrubber.scrub('{"token":"abc123"}');
      expect(out, '{"token":"[REDACTED]"}');
    });

    test('redacts password', () {
      final out = PiiScrubber.scrub('{"password":"secret"}');
      expect(out, '{"password":"[REDACTED]"}');
    });

    test('redacts patient_id', () {
      final out = PiiScrubber.scrub('{"patient_id":"uuid-x"}');
      expect(out, '{"patient_id":"[REDACTED]"}');
    });

    test('redacts practitioner_id', () {
      final out = PiiScrubber.scrub('{"practitioner_id":"uuid-y"}');
      expect(out, '{"practitioner_id":"[REDACTED]"}');
    });

    test('redacts bearer token', () {
      final out = PiiScrubber.scrub('Authorization: Bearer eyJhbGciOi...');
      expect(out, contains('[REDACTED]'));
      expect(out, isNot(contains('eyJhbGciOi')));
    });

    test('leaves clean string unchanged', () {
      const clean = 'Bonjour, world!';
      expect(PiiScrubber.scrub(clean), clean);
    });

    test('handles multiple sensitive fields', () {
      final out = PiiScrubber.scrub(
        '{"token":"t","password":"p","patient_id":"id"}',
      );
      expect(out, isNot(contains('"t"')));
      expect(out, isNot(contains('"p"')));
      expect(out, isNot(contains('"id"')));
      expect('[REDACTED]'.allMatches(out).length, greaterThanOrEqualTo(3));
    });
  });
}
