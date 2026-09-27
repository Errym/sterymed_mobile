// Task 2 (test coverage completion). Was an empty stub. LabelBlockedScreen
// only ever renders after LabelDetailBloc reaches a failure state — real
// backend behavior confirmed in the file's own doc comment:
// ResolveLabelScanAction always throws for a recalled/expired/voided
// label, never returns a success. Covers the 3 classified error codes plus
// the unclassified fallback, and the "new scan" action.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_repository.dart';
import 'package:steriymed_mobile/features/labels/presentation/screens/label_blocked_screen.dart';

import '../helpers/pump_app.dart';

class MockLabelRepository extends Mock implements LabelRepository {}

void main() {
  late MockLabelRepository repo;

  setUp(() {
    repo = MockLabelRepository();
  });

  Widget wrap(Widget child) => RepositoryProvider<LabelRepository>.value(
        value: repo,
        child: child,
      );

  testWidgets('LABEL_EXPIRED shows the expired title, icon, and message',
      (tester) async {
    when(() => repo.getByCode(any())).thenThrow(
      const ApiException(
        code: 'LABEL_EXPIRED',
        message: 'Cette étiquette a dépassé sa date limite d\'utilisation.',
      ),
    );

    await pumpApp(tester, wrap(const LabelBlockedScreen(code: 'LOT-1')));
    await tester.pumpAndSettle();

    expect(find.text('Étiquette expirée'), findsOneWidget);
    expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);
    expect(
      find.text('Cette étiquette a dépassé sa date limite d\'utilisation.'),
      findsOneWidget,
    );
  });

  testWidgets('LABEL_RECALLED shows the recalled title and icon',
      (tester) async {
    when(() => repo.getByCode(any())).thenThrow(
      const ApiException(code: 'LABEL_RECALLED', message: 'Lot rappelé.'),
    );

    await pumpApp(tester, wrap(const LabelBlockedScreen(code: 'LOT-2')));
    await tester.pumpAndSettle();

    expect(find.text('Étiquette rappelée'), findsOneWidget);
    expect(find.byIcon(Icons.report_gmailerrorred_outlined), findsOneWidget);
  });

  testWidgets('LABEL_VOIDED shows the voided title with the generic icon',
      (tester) async {
    when(() => repo.getByCode(any())).thenThrow(
      const ApiException(code: 'LABEL_VOIDED', message: 'Étiquette annulée.'),
    );

    await pumpApp(tester, wrap(const LabelBlockedScreen(code: 'LOT-3')));
    await tester.pumpAndSettle();

    expect(find.text('Étiquette annulée'), findsOneWidget);
    expect(find.byIcon(Icons.block), findsOneWidget);
  });

  testWidgets(
    'an unclassified error code falls back to the generic "blocked" title '
    'and shows the real backend message',
    (tester) async {
      // Note: the widget's own `state.error ?? '<default message>'` fallback
      // string is unreachable from a real failure state — LabelDetailBloc's
      // catch block always sets `error: e.message`, and ApiException.message
      // is non-nullable, so `state.error` can never actually be null here.
      // This test exercises the reachable path: whatever real message the
      // backend sent for an unclassified code.
      when(() => repo.getByCode(any())).thenThrow(
        const ApiException(
          code: 'SOME_OTHER_CODE',
          message: 'Cette étiquette a un statut non pris en charge.',
        ),
      );

      await pumpApp(tester, wrap(const LabelBlockedScreen(code: 'LOT-4')));
      await tester.pumpAndSettle();

      // Appears twice: the AppBar title is always "Étiquette bloquée",
      // and it's also this fallback branch's body title.
      expect(find.text('Étiquette bloquée'), findsNWidgets(2));
      expect(find.byIcon(Icons.block), findsOneWidget);
      expect(
        find.text('Cette étiquette a un statut non pris en charge.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows the "Nouveau scan" action', (tester) async {
    when(() => repo.getByCode(any())).thenThrow(
      const ApiException(code: 'LABEL_EXPIRED', message: 'x'),
    );

    await pumpApp(tester, wrap(const LabelBlockedScreen(code: 'LOT-1')));
    await tester.pumpAndSettle();

    expect(find.text('Nouveau scan'), findsOneWidget);
  });
}
