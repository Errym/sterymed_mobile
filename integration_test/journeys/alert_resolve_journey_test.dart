// Journey: alert -> resolve (Cahier §5 journey 5, first half).
//   A cycle fails a control test on the server, which raises a critical alert.
//   The admin sees it in the Alertes tab, resolves it, and the server no longer
//   lists it as open. A viewer sees alerts but is never offered the button.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../support/journey_helpers.dart';
import '../support/live_backend_guard.dart';
import '../support/web_env.dart';

Future<List<Map>> _openAlerts() async {
  final body = await ServerApi.get('/v1/alerts?filter[state]=open&limit=100') as Map;
  return (body['data'] as List).cast<Map>();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'failed control test raises an alert; admin resolves it; viewer cannot',
    (tester) async {
      // ---- server side: a cycle that fails a control test
      final device = await firstWhere('/v1/devices?limit=10', (_) => true);
      final cycle = (await ServerApi.post('/v1/cycles', {'device_id': device['id']}) as Map);
      final cycleId = ((cycle['data'] ?? cycle) as Map)['id'] as String;
      await ServerApi.post('/v1/cycles/$cycleId/items', {'description': 'Cassette alerte'});
      await ServerApi.post('/v1/cycles/$cycleId/start', {});
      await ServerApi.post('/v1/cycles/$cycleId/complete', {});
      await ServerApi.post('/v1/cycles/$cycleId/control-tests', {
        'type': 'bowie_dick',
        'result': 'fail',
        'performed_at': DateTime.now().toUtc().toIso8601String(),
      });
      final alert = (await _openAlerts()).firstWhere((a) => a['subject_id'] == cycleId);

      await launchApp(tester);
      await signIn(tester, 'admin');
      openScreen(tester, '/app/alerts');
      expect(
        await waitFor(tester, find.textContaining('control test'), seconds: 15),
        isTrue,
        reason: 'the new alert is listed',
      );

      await tapVisible(tester, find.text('Marquer comme résolu').first);
      await settle(tester, 1);
      expect(find.text('Résoudre l\'alerte ?'), findsOneWidget);
      await tester.tap(find.text('Résoudre'));
      await settle(tester, 3);

      final stillOpen = (await _openAlerts()).any((a) => a['id'] == alert['id']);
      expect(stillOpen, isFalse, reason: 'the server must hold the resolution');
      expectNoFrameError(tester, 'alert resolve journey');
      await signOut(tester);

      // ---- a viewer reads alerts and has no resolve button
      await signIn(tester, 'viewer');
      openScreen(tester, '/app/alerts');
      expect(await waitFor(tester, find.text('Alertes')), isTrue);
      await settle(tester, 2);
      expect(find.text('Marquer comme résolu'), findsNothing);
      await signOut(tester);
    },
    skip: kSkipUnlessLiveBackend,
  );
}
