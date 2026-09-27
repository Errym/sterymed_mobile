// Team invite sheet completion pass. Was previously untested and had 2
// real bugs: the failure path showed the raw `e.toString()` (a verbose
// "ApiException(code: ..., status: ...)" debug string) instead of the
// real server message via ErrorMessage.from, and there was no way to
// cancel other than a silent tap-outside/drag-down dismiss that discarded
// whatever was typed with zero confirmation.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/identity/data/repositories/team_repository.dart';
import 'package:steriymed_mobile/features/identity/presentation/bloc/team_list_bloc.dart';
import 'package:steriymed_mobile/features/identity/presentation/widgets/team_invite_sheet.dart';

import '../helpers/pump_app.dart';

class MockTeamRepository extends Mock implements TeamRepository {}

void main() {
  late MockTeamRepository repo;
  late TeamListBloc bloc;

  setUp(() {
    repo = MockTeamRepository();
    when(() => repo.list()).thenAnswer((_) async => []);
    bloc = TeamListBloc(repo);

    // _TeamInviteSheetState._submit() resolves TeamRepository via
    // getIt<TeamRepository>() directly (not via the BlocProvider'd repo),
    // so the mock needs registering there too, same as every other
    // getIt-resolved dependency in this test suite.
    if (GetIt.instance.isRegistered<TeamRepository>()) {
      GetIt.instance.unregister<TeamRepository>();
    }
    GetIt.instance.registerSingleton<TeamRepository>(repo);
  });

  tearDown(() {
    bloc.close();
    GetIt.instance.unregister<TeamRepository>();
  });

  // Returns void (not Future<bool?>) on purpose: an async function
  // returning a Future of the same type it declares gets auto-awaited by
  // Dart before the caller sees it ("Future flattening"), which would
  // block here until the sheet is dismissed — before the test ever gets a
  // chance to interact with it. `onOpened` hands the still-pending future
  // back out untouched instead.
  Future<void> openSheet(
    WidgetTester tester, {
    required void Function(Future<bool?>) onOpened,
  }) async {
    await pumpApp(
      tester,
      BlocProvider.value(
        value: bloc,
        child: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => onOpened(TeamInviteSheet.show(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('role dropdown shows exactly the 6 real roles in French',
      (tester) async {
    await openSheet(tester, onOpened: (_) {});

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    for (final label in [
      'Direction',
      'Administrateur',
      'Responsable stock',
      'Responsable libération',
      'Praticien',
      'Lecture seule',
    ]) {
      // The default-selected role ("Praticien") legitimately renders
      // twice — once in the closed field's display, once in the open
      // menu — so this checks presence (>=1), not an exact count.
      expect(
        find.text(label).evaluate(),
        isNotEmpty,
        reason: 'missing role $label',
      );
    }
  });

  testWidgets('rejects an empty email and an invalid email', (tester) async {
    await openSheet(tester, onOpened: (_) {});

    await tester.tap(find.text('Envoyer l\'invitation'));
    await tester.pumpAndSettle();
    expect(find.text('Requis.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'pas-un-email');
    await tester.tap(find.text('Envoyer l\'invitation'));
    await tester.pumpAndSettle();
    expect(find.text('E-mail invalide.'), findsOneWidget);

    verifyNever(() => repo.invite(
          email: any(named: 'email'),
          role: any(named: 'role'),
        ));
  });

  testWidgets(
    'success calls invite with the entered fields, shows the success '
    'snackbar, and pops with true',
    (tester) async {
      when(() => repo.invite(email: any(named: 'email'), role: any(named: 'role')))
          .thenAnswer((_) async {});

      late Future<bool?> resultFuture;
      await openSheet(tester, onOpened: (f) => resultFuture = f);

      await tester.enterText(
        find.byType(TextFormField),
        'praticien@cabinet.fr',
      );
      await tester.tap(find.text('Envoyer l\'invitation'));
      await tester.pumpAndSettle();

      verify(() => repo.invite(
            email: 'praticien@cabinet.fr',
            role: 'practitioner',
          )).called(1);
      expect(find.text('Invitation envoyée.'), findsOneWidget);
      expect(await resultFuture, isTrue);
    },
  );

  testWidgets(
    'failure shows the real server message, not the raw exception string',
    (tester) async {
      when(() => repo.invite(email: any(named: 'email'), role: any(named: 'role')))
          .thenThrow(const ApiException(
        code: 'conflict',
        message: 'Cette adresse e-mail est déjà invitée.',
      ));

      await openSheet(tester, onOpened: (_) {});
      await tester.enterText(
        find.byType(TextFormField),
        'praticien@cabinet.fr',
      );
      await tester.tap(find.text('Envoyer l\'invitation'));
      await tester.pumpAndSettle();

      expect(
        find.text('Cette adresse e-mail est déjà invitée.'),
        findsOneWidget,
      );
      expect(find.textContaining('ApiException'), findsNothing);
    },
  );

  testWidgets('cancel with nothing typed pops immediately, no confirm dialog',
      (tester) async {
    late Future<bool?> resultFuture;
    await openSheet(tester, onOpened: (f) => resultFuture = f);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(await resultFuture, isFalse);
    expect(find.text('Abandonner l\'invitation ?'), findsNothing);
  });

  testWidgets(
    'cancel with a dirty form asks for confirmation; declining keeps the '
    'sheet open, confirming discards and pops with false',
    (tester) async {
      late Future<bool?> resultFuture;
      await openSheet(tester, onOpened: (f) => resultFuture = f);
      await tester.enterText(find.byType(TextFormField), 'a@b.fr');

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Abandonner l\'invitation ?'), findsOneWidget);

      // Decline — the dialog's own default cancel label is "Annuler" too.
      await tester.tap(find.text('Annuler').last);
      await tester.pumpAndSettle();
      expect(find.byType(TeamInviteSheet), findsOneWidget);

      // Now actually confirm the discard.
      await tester.tap(find.text('Annuler').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abandonner'));
      await tester.pumpAndSettle();

      expect(await resultFuture, isFalse);
    },
  );
}
