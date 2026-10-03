// Journey: scan a label and record its use (Cahier §5 journey 3).
//   practitioner opens the scanner, types the label code (the camera path is
//   not automatable; the manual entry goes through exactly the same lookup),
//   the label detail opens, the use is recorded for a patient and a procedure
//   -> the server marks the label used, and using it AGAIN is refused.
//
// Needs a fresh seed: a label recalled by an earlier run (a non-conformity on
// its cycle) cannot be used. python scripts/seed_web_journeys.py

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../support/journey_helpers.dart';
import '../support/live_backend_guard.dart';
import '../support/web_env.dart';

Future<String> _status(String labelId) async {
  final body = await ServerApi.get('/v1/labels/$labelId') as Map;
  return ((body['data'] ?? body) as Map)['status'] as String;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'practitioner scans a fresh label, records the use, a second use is refused',
    (tester) async {
      final label = (await ServerApi.get('/v1/labels/${WebEnv.labelFresh}')) as Map;
      final urn = ((label['data'] ?? label) as Map)['urn'] as String;
      expect(await _status(WebEnv.labelFresh), isNot('used'));

      await launchApp(tester);
      await signIn(tester, 'practitioner');

      openScreen(tester, '/app/scanner');
      expect(await waitFor(tester, find.byTooltip('Saisir le code')), isTrue);
      await tester.tap(find.byTooltip('Saisir le code'));
      await settle(tester, 1);
      await tester.enterText(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
        urn,
      );
      await tester.tap(find.text('Vérifier'));
      expect(
        await waitFor(tester, find.text('Enregistrer utilisation'), seconds: 15),
        isTrue,
        reason: 'a fresh label opens its detail with the use action',
      );

      await tester.tap(find.text('Enregistrer utilisation'));
      expect(await waitFor(tester, find.text('Sélectionner un patient')), isTrue);
      await tester.tap(find.text('Sélectionner un patient'));
      await settle(tester, 1.5);
      await tester.tap(find.byType(ListTile).first);
      await settle(tester, 1);
      await tester.enterText(find.byType(TextFormField).first, 'Détartrage');
      await tapVisible(tester, find.text('Enregistrer').last);
      await settle(tester, 3);

      expect(await _status(WebEnv.labelFresh), 'used',
          reason: 'the server must hold the use, not only the screen');
      expectNoFrameError(tester, 'scanner usage journey');

      // using the same label again is refused by the server
      await expectLater(
        () => ServerApi.post('/v1/labels/${WebEnv.labelFresh}/usage', {
          'patient_id': WebEnv.patientId,
          'procedure': 'Second use',
        }),
        throwsA(isA<StateError>()),
      );
      await signOut(tester);
    },
    skip: kSkipUnlessLiveBackend,
  );
}
