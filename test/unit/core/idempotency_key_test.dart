import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/utils/idempotency_key.dart';

void main() {
  group('generateIdempotencyKey', () {
    test('returns a 36-char UUID v4 string', () {
      final key = generateIdempotencyKey();
      expect(key.length, 36);
    });

    test('matches UUID v4 regex', () {
      final key = generateIdempotencyKey();
      final re = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      );
      expect(re.hasMatch(key), isTrue, reason: 'got: $key');
    });

    test('generates unique keys', () {
      final a = generateIdempotencyKey();
      final b = generateIdempotencyKey();
      expect(a, isNot(b));
    });

    test('generates 100 unique keys', () {
      final set = <String>{};
      for (var i = 0; i < 100; i++) {
        set.add(generateIdempotencyKey());
      }
      expect(set.length, 100);
    });
  });
}
