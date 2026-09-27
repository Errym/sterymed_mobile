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

  group('Env.checkSecureTransport', () {
    test('throws when production points at a plaintext http:// backend', () {
      expect(
        () => Env.checkSecureTransport(
          isProduction: true,
          apiBaseUrl: 'http://api.example.com/api',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('passes when production uses https://', () {
      expect(
        () => Env.checkSecureTransport(
          isProduction: true,
          apiBaseUrl: 'https://api.example.com/api',
        ),
        returnsNormally,
      );
    });

    test('passes for a non-production http:// default (dev/staging)', () {
      expect(
        () => Env.checkSecureTransport(
          isProduction: false,
          apiBaseUrl: 'http://10.0.2.2:8000/api',
        ),
        returnsNormally,
      );
    });
  });
}
