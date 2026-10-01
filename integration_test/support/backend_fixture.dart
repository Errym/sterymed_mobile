import 'dart:convert';

import 'package:http/http.dart' as http;

import 'test_user.dart';

/// Checks the fixture server before boot can restore sessions or replay writes.
/// Seeding/resetting remains an explicit host-side operation in the fixture kit.
Future<void> verifyFixtureBackend({
  FixtureTestConfig config = TestUser.config,
  http.Client? client,
}) async {
  config.validate();
  final connection = client ?? http.Client();
  try {
    final response = await connection
        .get(config.markerUri)
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw StateError('The isolated clinic fixture server is not ready.');
    }
    final marker = jsonDecode(response.body);
    if (marker is! Map ||
        marker['fixture_id'] != FixtureTestConfig.expectedFixtureId ||
        marker['database'] != FixtureTestConfig.expectedDatabase ||
        marker['tenant_ids'] is! List ||
        !(marker['tenant_ids'] as List).contains(config.tenantId) ||
        marker['device_ids'] is! List ||
        !(marker['device_ids'] as List).contains(config.deviceId)) {
      throw StateError(
        'Refusing live tests: server fixture identity mismatch.',
      );
    }
  } finally {
    if (client == null) connection.close();
  }
}
