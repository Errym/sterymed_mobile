// Journey 2: Full cycle lifecycle — Gate 6 item 1.
//
// create -> start -> complete -> submit-for-release -> release (compliant).
// Requires the isolated clinic fixture's site/device/program and a fresh test
// install. Credentials and expected identities come from its generated defines.
//
//   flutter test integration_test/journeys/cycle_lifecycle_journey_test.dart \
//     -d <device-id> \
//     --dart-define-from-file=build/clinic-fixture/flutter_defines.json
//
// Skipped by default (see ../support/live_backend_guard.dart) so a bare
// `flutter test integration_test/` — which some Flutter/`integration_test`
// versions can run headlessly with no device flag — doesn't hang or fail
// trying to reach a backend that isn't there.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:steriymed_mobile/app.dart';
import 'package:steriymed_mobile/bootstrap.dart';

import '../support/live_backend_guard.dart';
import '../support/web_env.dart';

Future<void> _login(WidgetTester tester) async {
  await bootstrap(() => const SteryMedApp());
  await tester.pumpAndSettle(const Duration(seconds: 2));

  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), WebEnv.slug);
  await tester.enterText(fields.at(1), WebEnv.emailOwner);
  await tester.enterText(fields.at(2), WebEnv.password);
  await tester.pump();
  await tester.tap(find.text('Se connecter'));
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

Future<void> _confirmDialog(WidgetTester tester, String confirmLabel) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text(confirmLabel));
  await tester.pumpAndSettle(const Duration(seconds: 2));
  // Every transition success shows a "Cycle mis à jour." SnackBar right
  // over the action button; pumpAndSettle() doesn't wait out its ~4s
  // static hold (only its enter/exit transitions schedule frames), so
  // the next tap lands on the SnackBar instead of the button underneath.
  await tester.pump(const Duration(seconds: 4));
}

/// The detail screen is a plain `ListView`, which still lazily mounts
/// elements outside the viewport (sliver machinery) — so the action
/// button at the bottom of a long cycle often isn't in the widget tree
/// until we scroll to it, even though it renders fine visually.
Future<void> _tapVisible(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'create -> start -> complete -> submit -> release (compliant)',
      (tester) async {
    await _login(tester);
    expect(find.text('Accueil'), findsOneWidget);

    // ── Cycles tab -> create ──
    await tester.tap(find.text('Cycles'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Nouveau Cycle'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Device + programme auto-select to the only seeded ones.
    expect(find.text(WebEnv.deviceName), findsOneWidget,
        reason: 'the seeded device should be auto-selected');

    await tester.tap(find.text('Initialiser & Charger les Sachets'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Back on the cycle list — open the newly created cycle.
    expect(find.textContaining('Cycle #'), findsWidgets);
    await tester.tap(find.textContaining('Cycle #').first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // ── Add an instrument — the backend rejects `start` on an empty load
    // ("At least one item must be in the load before starting the cycle.",
    // StartCycleAction.php:26). "Initialiser & Charger les Sachets" only
    // creates the cycle shell; items are added here, one at a time.
    final addInstrument = find.byTooltip('Ajouter un instrument');
    await tester.scrollUntilVisible(
      addInstrument,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(addInstrument);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Description *'), 'Cassette Gate6');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // Not asserting on "Instruments (1)" here — scrollUntilVisible has
    // proven flaky on-device right after this particular refresh (the
    // list rebuilds mid-drag and the Scrollable lookup transiently
    // finds nothing). The item's presence is already confirmed via the
    // POST 201 + follow-up GET in the request log above; `_tapVisible`
    // below re-verifies the app moved on correctly.
    //
    // The "Instrument ajouté." success SnackBar sits right over the
    // action button and has no animation during its ~4s hold — only its
    // enter/exit transitions schedule frames — so pumpAndSettle() returns
    // while it's still fully opaque and swallows the next tap. Wait out
    // its real-time duration before proceeding.
    await tester.pump(const Duration(seconds: 4));

    // ── Démarrer ──
    await _tapVisible(tester, 'Démarrer le cycle');
    await _confirmDialog(tester, 'Démarrer');
    expect(find.text('Marquer comme terminé'), findsOneWidget,
        reason: 'status should now be in_progress');

    // ── Terminer ──
    await _tapVisible(tester, 'Marquer comme terminé');
    await _confirmDialog(tester, 'Terminer');
    expect(find.text('Soumettre pour libération'), findsOneWidget,
        reason: 'status should now be completed');

    // ── Soumettre ──
    await _tapVisible(tester, 'Soumettre pour libération');
    await _confirmDialog(tester, 'Soumettre');
    expect(find.text('Prendre la décision de libération'), findsOneWidget,
        reason: 'status should now be awaiting_release');

    // ── Décision de libération: Conforme (default selection) ──
    await _tapVisible(tester, 'Prendre la décision de libération');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Conforme — libérer le cycle'), findsOneWidget);

    await _tapVisible(tester, 'Valider la décision');
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // The release card itself ("Cycle conforme") sits below the fold and
    // scrollUntilVisible has proven flaky right after this particular
    // refresh (occasionally throws "Bad state: No element" mid-drag on
    // device — the Scrollable lookup races the rebuild). The status
    // badge in the header (index 0) is driven by the same fetched
    // CycleData.status and is just as strong a proof the release applied
    // server-side — but the screen doesn't reliably reset scroll to top
    // on refresh (we'd previously scrolled down to reach the release
    // button), so scroll *up* to guarantee reaching the header rather
    // than assuming either direction.
    final statusBadge = find.text('Libéré');
    await tester.scrollUntilVisible(
      statusBadge,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(statusBadge, findsOneWidget,
        reason: 'CycleStatusBadge shows "Libéré" only for status == '
            '"released", fetched fresh after the release call — proves '
            'the full lifecycle applied server-side');
  }, skip: kSkipUnlessLiveBackend);
}
