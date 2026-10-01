import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../integration_test/support/backend_fixture.dart';
import '../../../integration_test/support/test_user.dart';

FixtureTestConfig _config({
  String url = 'http://127.0.0.1:18010/api',
  String environment = 'dev',
  String fixtureId = FixtureTestConfig.expectedFixtureId,
  String password = 'synthetic-test-password',
  String email = 'admin@fixture.example.invalid',
  String deviceId = 'fixture-device',
}) => FixtureTestConfig(
  apiBaseUrl: url,
  environment: environment,
  fixtureId: fixtureId,
  tenantSlug: 'fixture-populated',
  tenantId: 'fixture-tenant',
  adminEmail: email,
  adminPassword: password,
  deviceName: 'Fixture Autoclave',
  deviceId: deviceId,
  programId: 'fixture-program',
);

Map<String, Object> _marker() => {
  'fixture_id': FixtureTestConfig.expectedFixtureId,
  'database': FixtureTestConfig.expectedDatabase,
  'tenant_ids': ['fixture-tenant'],
  'device_ids': ['fixture-device'],
};

void main() {
  group('live fixture target guard', () {
    for (final host in ['localhost', '127.0.0.1', '10.0.2.2', '[::1]']) {
      test('accepts isolated local server $host', () {
        final config = _config(url: 'http://$host:18010/api/');
        expect(config.validate, returnsNormally);
        expect(config.markerUri.path, '/__clinic_fixture');
      });
    }

    for (final url in [
      'https://clinic.example.com:18010/api',
      'http://127.0.0.1:8010/api',
      'http://127.0.0.1:18010/api/v1',
      'http://127.0.0.1:18010/api?tenant=real',
      'http://127.0.0.1:18010/api#real',
      'http://user:password@127.0.0.1:18010/api',
      'file:///api',
    ]) {
      test('rejects non-fixture target $url', () {
        expect(_config(url: url).validate, throwsStateError);
      });
    }

    test('rejects production configuration', () {
      expect(_config(environment: 'production').validate, throwsStateError);
    });

    test('requires generated fixture identities and synthetic credentials', () {
      for (final config in [
        _config(fixtureId: ''),
        _config(password: ''),
        _config(email: 'staff@clinic.example.com'),
        _config(deviceId: ''),
      ]) {
        expect(config.validate, throwsStateError);
      }
    });
  });

  group('live fixture server preflight', () {
    test('only performs a read of the server identity before boot', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(_marker()), 200);
      });
      addTearDown(client.close);

      await verifyFixtureBackend(config: _config(), client: client);

      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/__clinic_fixture');
      expect(requests.single.headers.containsKey('authorization'), isFalse);
    });

    test('invalid configuration makes no network request', () async {
      var requested = false;
      final client = MockClient((_) async {
        requested = true;
        return http.Response('{}', 200);
      });
      addTearDown(client.close);

      await expectLater(
        verifyFixtureBackend(
          config: _config(fixtureId: ''),
          client: client,
        ),
        throwsStateError,
      );
      expect(requested, isFalse);
    });

    for (final field in [
      'fixture_id',
      'database',
      'tenant_ids',
      'device_ids',
    ]) {
      test('rejects mismatched server $field', () async {
        final marker = _marker()..[field] = 'not-the-fixture';
        final client = MockClient(
          (_) async => http.Response(jsonEncode(marker), 200),
        );
        addTearDown(client.close);
        await expectLater(
          verifyFixtureBackend(config: _config(), client: client),
          throwsStateError,
        );
      });
    }

    test('rejects unavailable or malformed marker endpoints', () async {
      for (final response in [
        http.Response('not found', 404),
        http.Response('[]', 200),
        http.Response('not JSON', 200),
      ]) {
        final client = MockClient((_) async => response);
        addTearDown(client.close);
        await expectLater(
          verifyFixtureBackend(config: _config(), client: client),
          throwsA(anyOf(isA<StateError>(), isA<FormatException>())),
        );
      }
    });
  });
}
