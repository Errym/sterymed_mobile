import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/utils/pii_scrubber.dart';

void main() {
  piiExtendedTests();
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

void piiExtendedTests() {
  group('PiiScrubber.scrub identity and free-text fields', () {
    test('redacts a patient name in JSON', () {
      final out = PiiScrubber.scrub('{"name":"Jean Dupont","qty":3}');
      expect(out, isNot(contains('Dupont')));
      expect(out, contains('"qty":3'));
    });

    test('redacts a name in Dart Map.toString() form (what logs print)', () {
      final out = PiiScrubber.scrub({'name': 'Jean Dupont', 'qty': 3}.toString());
      expect(out, isNot(contains('Dupont')));
      expect(out, contains('qty: 3'));
    });

    test('redacts reference, notes and comments', () {
      for (final key in [
        'patient_reference',
        'reference',
        'notes',
        'procedure',
        'description',
        'administrative_comments',
        'phone',
      ]) {
        final out = PiiScrubber.scrub('{"$key":"secret value"}');
        expect(out, isNot(contains('secret value')), reason: key);
      }
    });

    test('redacts an email address anywhere in a message', () {
      final out = PiiScrubber.scrub('Echec pour awa.diop@cabinet.fr (422)');
      expect(out, isNot(contains('awa.diop')));
      expect(out, contains('422'));
    });

    test('does not eat unrelated words that merely contain a key', () {
      expect(PiiScrubber.scrub('username: kept'), 'username: kept');
    });
  });
}
