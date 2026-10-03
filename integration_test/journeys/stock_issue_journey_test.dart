// Journey: issue stock (Cahier §5 journey 3, "record exit without double-count").
//   stock manager issues 3 of the seeded lot -> the server holds 17
//   -> asking for more than is available is refused before anything is sent
//   -> a double tap on "Enregistrer la sortie" issues ONCE, not twice.
//
//   scripts/seed_web_journeys.py, then
//   scripts/run_web_journeys.sh journeys/stock_issue_journey_test.dart
// (or `flutter drive` on a device with build/web-journeys/defines.json).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:steriymed_mobile/shared/widgets/inputs/quantity_stepper.dart';
import '../support/journey_helpers.dart';
import '../support/live_backend_guard.dart';
import '../support/web_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'stock manager: issue with read-back, over-limit refused, double tap once',
    (tester) async {
      await launchApp(tester);
      await signIn(tester, 'stock_manager');
      final start = await ServerApi.stockOf(WebEnv.glovesLot, 'Reserve');
      expect(start, greaterThanOrEqualTo(10), reason: 'seeded lot has stock');

      // ---- issue 3
      openScreen(tester, '/app/stock/issue');
      expect(await waitFor(tester, find.byKey(const ValueKey('source_field'))), isTrue);
      await pickSeededLot(tester);
      expect(find.text('Disponible : $start boite'), findsOneWidget);
      await tester.enterText(_qtyField(), '3');
      await tapVisible(tester, find.text('Enregistrer la sortie'));
      expect(await waitFor(tester, find.text('Sortie enregistrée.')), isTrue);
      await settle(tester, 1);
      expect(await ServerApi.stockOf(WebEnv.glovesLot, 'Reserve'), start - 3);

      // ---- more than available: refused on the form, nothing sent
      openScreen(tester, '/app/stock/issue');
      expect(await waitFor(tester, find.byKey(const ValueKey('source_field'))), isTrue);
      await pickSeededLot(tester);
      await tester.enterText(_qtyField(), '${start + 50}');
      await tapVisible(tester, find.text('Enregistrer la sortie'));
      await settle(tester, 1);
      expect(find.textContaining('Maximum ${start - 3}'), findsOneWidget);
      expect(await ServerApi.stockOf(WebEnv.glovesLot, 'Reserve'), start - 3);

      // ---- double tap: two taps in the same frame must issue exactly once
      openScreen(tester, '/app/stock/issue');
      expect(await waitFor(tester, find.byKey(const ValueKey('source_field'))), isTrue);
      await pickSeededLot(tester);
      await tester.enterText(_qtyField(), '2');
      final save = find.text('Enregistrer la sortie');
      await tester.scrollUntilVisible(
        save,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(save);
      await tester.tap(save, warnIfMissed: false);
      expect(await waitFor(tester, find.text('Sortie enregistrée.')), isTrue);
      await settle(tester, 2);
      expect(
        await ServerApi.stockOf(WebEnv.glovesLot, 'Reserve'),
        start - 3 - 2,
        reason: 'a double tap must not issue twice',
      );
      expectNoFrameError(tester, 'stock issue journey');
      await signOut(tester);
    },
    skip: kSkipUnlessLiveBackend,
  );
}

/// The quantity box inside the stepper (the lot picker is also a text field).
Finder _qtyField() => find.descendant(
      of: find.byType(QuantityStepper),
      matching: find.byType(TextField),
    );
