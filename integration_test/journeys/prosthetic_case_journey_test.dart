// Journey P: the prosthetic case lifecycle as the practitioner, in real Chrome
// against the dev backend, with server read-back after every step.
//   case on the dashboard -> open it -> impression -> sent -> received ->
//   it appears on the waiting list -> scheduled (planned date) -> placed
//   (critical, asks to confirm) -> history shows every transition with its note.
// The practitioner never sees a transition the server would refuse, and a
// viewer can read the case but is offered no action.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../support/web_env.dart';

Future<Map> _case(String id) async =>
    (await ServerApi.get('/v1/prosthetic-cases/$id') as Map)['data'] as Map;

Future<bool> _isWaiting(String id) async {
  final body = await ServerApi.get(
    '/v1/prosthetic-cases?scope=waiting_for_placement&limit=100',
  ) as Map;
  return (body['data'] as List).cast<Map>().any((c) => c['id'] == id);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await settle(tester, 0.3);
  await tester.tap(f);
}

/// Opens the status dialog for [label], types [note] and confirms.
Future<void> _transition(
  WidgetTester tester,
  String label, {
  required String confirm,
  String? note,
}) async {
  await _tap(tester, find.widgetWithText(OutlinedButton, label));
  await settle(tester, 1);
  expect(
    find.byType(AlertDialog),
    findsOneWidget,
    reason: 'every status change asks for a note / confirmation',
  );
  if (note != null) {
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      note,
    );
    await tester.pump();
  }
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(confirm),
    ),
  );
  await settle(tester, 2);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('practitioner: full prosthetic lifecycle with read-back', (
    tester,
  ) async {
    // ---- set-up the server side: one fresh case for this run
    final labs =
        (await ServerApi.get('/v1/laboratories') as Map)['data'] as List;
    final labId = labs
        .cast<Map>()
        .firstWhere((l) => l['name'] == WebEnv.labName)['id'] as String;
    final created = (await ServerApi.post('/v1/prosthetic-cases', {
      'patient_id': WebEnv.patientId,
      'practitioner_id': WebEnv.ownerId,
      'laboratory_id': labId,
      'impression_type': 'digital',
      'work_type': 'crown',
      'impression_date': DateTime.now()
          .subtract(const Duration(days: 3))
          .toIso8601String()
          .split('T')
          .first,
    }) as Map)['data'] as Map;
    final id = created['id'] as String;
    final reference = created['patient_reference'] as String;
    expect(created['status'], 'impression_completed');

    await launchApp(tester);
    await signIn(tester, 'practitioner');

    // ---- the dashboard shows the cards, the case opens
    openScreen(tester, '/app/prosthetic');
    expect(await waitFor(tester, find.text('Travaux actifs')), isTrue);
    expectNoFrameError(tester, 'prosthetic dashboard');

    openScreen(tester, '/app/prosthetic/$id');
    expect(
      await waitFor(tester, find.text(reference)),
      isTrue,
      reason: 'the case detail shows the pseudonymous reference',
    );
    expect(find.text('Empreinte réalisée'), findsWidgets);

    // The server would refuse impression -> placed, so the app never offers it.
    expect(find.widgetWithText(OutlinedButton, 'Posé'), findsNothing);

    // ---- impression -> sent
    await _transition(
      tester,
      'Envoyé au laboratoire',
      confirm: 'Valider',
      note: 'Envoi express',
    );
    expect((await _case(id))['status'], 'sent_to_laboratory');
    expect(await _isWaiting(id), isFalse, reason: 'still at the laboratory');

    // ---- sent -> received: it joins the waiting list with no manual edit
    await _transition(tester, 'Reçu au cabinet', confirm: 'Valider');
    expect((await _case(id))['status'], 'received_at_practice');
    expect(await _isWaiting(id), isTrue);

    openScreen(tester, '/app/prosthetic/waiting-placement');
    expect(
      await waitFor(tester, find.byKey(Key('waiting-open-$id'))),
      isTrue,
      reason: 'the waiting list shows the case with its quick actions',
    );
    expectNoFrameError(tester, 'waiting placement');

    // ---- received -> scheduled (the planned date is prefilled)
    openScreen(tester, '/app/prosthetic/$id');
    expect(await waitFor(tester, find.text(reference)), isTrue);
    await _transition(tester, 'Pose programmée', confirm: 'Valider');
    final scheduled = await _case(id);
    expect(scheduled['status'], 'placement_scheduled');
    expect(scheduled['planned_placement_date'], isNotNull);

    // ---- scheduled -> placed is critical: the dialog says so
    await _tap(tester, find.widgetWithText(OutlinedButton, 'Posé'));
    await settle(tester, 1);
    expect(find.text('Confirmer la pose ?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Confirmer'),
      ),
    );
    await settle(tester, 2);
    final placed = await _case(id);
    expect(placed['status'], 'placed');
    expect(placed['actual_placement_date'], isNotNull);
    expect(await _isWaiting(id), isFalse, reason: 'placed leaves the list');

    // ---- the history holds every step, in order, with the typed note
    final history = (await ServerApi.get(
      '/v1/prosthetic-cases/$id/status-history',
    ) as Map)['data'] as List;
    expect(history.cast<Map>().map((h) => h['to_status']).toList(), [
      'impression_completed',
      'sent_to_laboratory',
      'received_at_practice',
      'placement_scheduled',
      'placed',
    ]);
    expect(
      history.cast<Map>().any((h) => h['note'] == 'Envoi express'),
      isTrue,
      reason: 'the note typed in the dialog reached the server',
    );
    expectNoFrameError(tester, 'prosthetic lifecycle');

    // ---- a viewer reads the case but is offered no action
    await signOut(tester);
    await signIn(tester, 'viewer');
    openScreen(tester, '/app/prosthetic/$id');
    expect(await waitFor(tester, find.text(reference)), isTrue);
    expect(find.text('Changer le statut'), findsNothing);
    expectNoFrameError(tester, 'viewer prosthetic detail');
  });
}
