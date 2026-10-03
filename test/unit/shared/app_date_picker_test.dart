import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/shared/widgets/inputs/app_date_picker.dart';

void main() {
  final first = DateTime(2026, 1, 1);
  final last = DateTime(2026, 9, 1);

  test('a date inside the range is kept', () {
    final d = DateTime(2026, 5, 5);
    expect(AppDatePicker.clampInitialDate(d, first, last), d);
  });

  test('today after a past upper bound opens on that bound, not outside the range', () {
    expect(AppDatePicker.clampInitialDate(DateTime(2026, 10, 2), first, last), last);
  });

  test('a date before the lower bound opens on that bound', () {
    expect(AppDatePicker.clampInitialDate(DateTime(2025, 1, 1), first, last), first);
  });
}
