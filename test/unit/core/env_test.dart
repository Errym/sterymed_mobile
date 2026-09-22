import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/config/env.dart';

void main() {
  group('Env', () {
    test('apiBaseUrl defaults to local emulator loopback', () {
      expect(Env.apiBaseUrl, 'http://10.0.2.2:8000/api');
    });

    test('environment defaults to dev', () {
      expect(Env.environment, 'dev');
    });

    test('sentryDsn defaults to empty', () {
      expect(Env.sentryDsn, isEmpty);
    });

    test('isDev/isStaging/isProduction reflect environment', () {
      expect(Env.isDev, isTrue);
      expect(Env.isStaging, isFalse);
      expect(Env.isProduction, isFalse);
    });
  });
}
