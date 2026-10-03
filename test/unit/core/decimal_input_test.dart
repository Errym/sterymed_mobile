import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/utils/decimal_input.dart';

void main() {
  group('DecimalInput.parse', () {
    test('reads French and English decimals', () {
      expect(DecimalInput.parse('120,50'), 120.5);
      expect(DecimalInput.parse('120.50'), 120.5);
      expect(DecimalInput.parse('  7 '), 7);
      expect(DecimalInput.parse(',5'), isNull); // no integer part: unclear
    });

    test('accepts thousands separators of either style', () {
      expect(DecimalInput.parse('1 200,5'), 1200.5);
      expect(DecimalInput.parse('1 200,50'), 1200.5);
      expect(DecimalInput.parse('1.200,50'), 1200.5);
      expect(DecimalInput.parse('1,200.50'), 1200.5);
    });

    test('rejects what is not an amount', () {
      for (final bad in ['abc', '12a', '-5', '1,2,3x', '12,345', '--', '€5']) {
        expect(DecimalInput.parse(bad), isNull, reason: bad);
      }
    });

    test('empty is not an amount and not an error', () {
      expect(DecimalInput.parse(''), isNull);
      expect(DecimalInput.parse(null), isNull);
      expect(DecimalInput.isInvalid(''), isFalse);
      expect(DecimalInput.isInvalid('   '), isFalse);
    });

    test('isInvalid flags typed text that cannot be read', () {
      expect(DecimalInput.isInvalid('12a'), isTrue);
      expect(DecimalInput.isInvalid('12,50'), isFalse);
    });

    test('maxDecimals is honoured', () {
      expect(DecimalInput.parse('1,2345', maxDecimals: 4), 1.2345);
      expect(DecimalInput.parse('1,2345'), isNull);
    });
  });
}
