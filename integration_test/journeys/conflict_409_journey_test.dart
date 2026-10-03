// Journey: a conflict is refused and shown, never silently applied.
//   The phone opens an issue form that says "Disponible : N". While it is open,
//   someone else (here: the API) takes ALL of that stock. The phone then submits
//   its own issue. The server must refuse it (not go negative) and the phone
//   must not claim success.

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
    'stock taken by someone else while the form is open: refused, stock never negative',
    (tester) async {
      await launchApp(tester);
      await signIn(tester, 'stock_manager');

      final level = await firstWhere(
        '/v1/stock-levels?limit=200',
        (r) => r['batch_number'] == WebEnv.glovesLot && r['location_name'] == 'Reserve',
      );
      final left = (level['quantity'] as num).toInt();
      expect(left, greaterThan(1), reason: 'seeded lot needs stock to fight over');

      openScreen(tester, '/app/stock/issue');
      expect(await waitFor(tester, find.byKey(const ValueKey('source_field'))), isTrue);
      await pickSeededLot(tester);
      expect(find.text('Disponible : $left boite'), findsOneWidget);

      // The other person takes everything.
      await ServerApi.post('/v1/stock-movements/issue', {
        'batch_id': level['batch_id'],
        'location_id': level['location_id'],
        'qty': left,
      });
      expect(await ServerApi.stockOf(WebEnv.glovesLot, 'Reserve'), 0);

      // The phone still believes `left` is available and submits 1.
      await tester.enterText(_qtyField(), '1');
      await tapVisible(tester, find.text('Enregistrer la sortie'));
      await settle(tester, 3);

      expect(find.text('Sortie enregistrée.'), findsNothing,
          reason: 'the phone must not claim a success the server refused');
      expect(await ServerApi.stockOf(WebEnv.glovesLot, 'Reserve'), 0,
          reason: 'stock must never go below zero');
      expectNoFrameError(tester, 'conflict journey');
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
