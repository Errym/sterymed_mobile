// Journey 1: Login.
//
// Run against a live local `steriqore` backend (`docker compose up -d` in
// that repo) on the default dev port:
//   flutter test integration_test/journeys/auth_journey_test.dart -d chrome \
//     --dart-define=API_BASE_URL=http://localhost:8010/api --dart-define=ENV=dev
//
// This is the first real content in integration_test/ — every file here
// was previously a 0-byte stub (see docs/TESTING.md). Written as part of
// the Gate 5/Gate 6 device-test effort: driving the app through its own
// widget tree (find.text/tester.tap) is far more reliable than pixel-
// coordinate browser automation, which proved too flaky in this
// environment to trust as evidence.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:steriymed_mobile/app.dart';
import 'package:steriymed_mobile/bootstrap.dart';

import '../support/test_user.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login with valid credentials reaches the dashboard shell',
      (tester) async {
    await bootstrap(() => const SteryMedApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Bienvenue'), findsOneWidget,
        reason: 'should start on the login screen with no stored session');

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), TestUser.tenantSlug);
    await tester.enterText(fields.at(1), TestUser.adminEmail);
    await tester.enterText(fields.at(2), TestUser.adminPassword);
    await tester.pump();

    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Accueil'), findsOneWidget,
        reason:
            'a successful login should land on the dashboard shell, whose '
            'bottom nav always shows Accueil');
    expect(find.text('Bienvenue'), findsNothing);
  });
}
