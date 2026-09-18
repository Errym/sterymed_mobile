import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/utils/validators.dart';

void main() {
  group('Validators.required', () {
    test('returns error for null', () {
      expect(Validators.required(null), isNotNull);
    });
    test('returns error for empty string', () {
      expect(Validators.required(''), isNotNull);
    });
    test('returns error for whitespace only', () {
      expect(Validators.required('   '), isNotNull);
    });
    test('returns null for valid value', () {
      expect(Validators.required('ok'), isNull);
    });
    test('uses custom field name', () {
      final result = Validators.required(null, field: 'Le nom');
      expect(result, contains('Le nom'));
    });
  });

  group('Validators.email', () {
    test('returns error for null', () {
      expect(Validators.email(null), isNotNull);
    });
    test('returns error for empty', () {
      expect(Validators.email(''), isNotNull);
    });
    test('returns error for missing @', () {
      expect(Validators.email('invalid'), isNotNull);
    });
    test('returns error for missing domain', () {
      expect(Validators.email('a@b'), isNotNull);
    });
    test('returns null for valid email', () {
      expect(Validators.email('a@b.com'), isNull);
    });
    test('returns null for email with plus tag', () {
      expect(Validators.email('user+tag@example.co.uk'), isNull);
    });
  });

  group('Validators.password', () {
    test('returns error for null', () {
      expect(Validators.password(null), isNotNull);
    });
    test('returns error for empty', () {
      expect(Validators.password(''), isNotNull);
    });
    test('returns error for too short', () {
      expect(Validators.password('short'), isNotNull);
    });
    test('returns null for 8+ chars', () {
      expect(Validators.password('12345678'), isNull);
    });
    test('returns null for long password', () {
      expect(Validators.password('a_very_strong_password'), isNull);
    });
  });
}
