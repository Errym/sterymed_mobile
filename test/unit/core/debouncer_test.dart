import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/utils/debouncer.dart';

void main() {
  group('Debouncer', () {
    test('fires once after delay', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 50));
      var count = 0;
      debouncer.run(() => count++);
      debouncer.run(() => count++);
      debouncer.run(() => count++);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(count, 1);
    });

    test('cancel prevents firing', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 50));
      var count = 0;
      debouncer.run(() => count++);
      debouncer.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(count, 0);
    });

    test('fires again for new calls after previous fire', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 30));
      var count = 0;
      debouncer.run(() => count++);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      debouncer.run(() => count++);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(count, 2);
    });
  });
}
