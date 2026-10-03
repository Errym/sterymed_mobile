// Journey: the waiting-for-placement list and its quick action (Prosthetic
// Brief §9). Three cases are brought to "received at practice" through the API;
// the practitioner finds them on the list, schedules one from the list with the
// quick action, and the server then holds that status and planned date.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../support/journey_helpers.dart';
import '../support/live_backend_guard.dart';
import '../support/web_env.dart';

Future<String> _receivedCase() async {
  final created = (await ServerApi.post('/v1/prosthetic-cases', {
    'patient_id': WebEnv.patientId,
    'practitioner_id': WebEnv.ownerId,
    'impression_type': 'digital',
    'work_type': 'crown',
    'impression_date': DateTime.now()
        .subtract(const Duration(days: 20))
        .toIso8601String()
        .split('T')
        .first,
  }) as Map);
  final id = ((created['data'] ?? created) as Map)['id'] as String;
  await ServerApi.post('/v1/prosthetic-cases/$id/status', {'status': 'sent_to_laboratory'});
  await ServerApi.post('/v1/prosthetic-cases/$id/status', {'status': 'received_at_practice'});
  return id;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'waiting list shows received cases; the quick action schedules one',
    (tester) async {
      final ids = [await _receivedCase(), await _receivedCase(), await _receivedCase()];

      await launchApp(tester);
      await signIn(tester, 'practitioner');
      openScreen(tester, '/app/prosthetic/waiting-placement');
      for (final id in ids) {
        expect(
          await waitFor(tester, find.byKey(Key('waiting-open-$id')), seconds: 15),
          isTrue,
          reason: 'every received, unplaced case is on the list',
        );
      }
      expectNoFrameError(tester, 'waiting placement list');

      // quick action: schedule the first one (the picker opens on tomorrow)
      await tapVisible(tester, find.byKey(Key('waiting-schedule-${ids.first}')));
      await settle(tester, 1);
      await tester.tap(find.text('OK'));
      await settle(tester, 3);

      final body = await ServerApi.get('/v1/prosthetic-cases/${ids.first}') as Map;
      final c = (body['data'] ?? body) as Map;
      expect(c['status'], 'placement_scheduled');
      expect(c['planned_placement_date'], isNotNull);
      expectNoFrameError(tester, 'waiting placement schedule');
      await signOut(tester);
    },
    skip: kSkipUnlessLiveBackend,
  );
}
