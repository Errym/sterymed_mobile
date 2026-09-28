import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/config/env.dart';

void main() {
  group('Env.stripTrailingSlash', () {
    test('strips a single trailing slash', () {
      expect(
        Env.stripTrailingSlash('https://api.example.com/api/'),
        'https://api.example.com/api',
      );
    });

    test('leaves a URL without a trailing slash untouched', () {
      expect(
        Env.stripTrailingSlash('https://api.example.com/api'),
        'https://api.example.com/api',
      );
    });
  });

  group('Env.resolvedApiBaseUrl', () {
    test('matches apiBaseUrl when there is no trailing slash to strip', () {
      expect(Env.apiBaseUrl, 'http://10.0.2.2:8000/api');
      expect(Env.resolvedApiBaseUrl, Env.apiBaseUrl);
    });

    test('never leaves a trailing slash, regardless of apiBaseUrl', () {
      expect(Env.resolvedApiBaseUrl.endsWith('/'), isFalse);
    });
  });
}
