// The Cycles tab: every cycle belongs to exactly one stage and the numbers add
// up, so a cycle can never "disappear" between the overview and the list.
// (A real phone showed 12 open cycles on the dashboard and "En cours (0)" here
// because draft cycles had no stage.)

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/cycle_repository.dart';
import 'package:steriymed_mobile/features/cycles/presentation/screens/cycle_list_screen.dart';

import '../fixtures/cycle_fixture.dart';
import '../helpers/pump_app.dart';
import '../mocks/mock_repositories.dart';

class _Session extends Mock implements SessionStore {}

void main() {
  late MockCycleRepository repo;

  setUp(() {
    repo = MockCycleRepository();
    when(() => repo.list(forceRefresh: true)).thenAnswer(
      (_) async => CursorPage(items: [
        buildCycle(id: 'a', number: '1', status: 'created'),
        buildCycle(id: 'b', number: '2', status: 'created'),
        buildCycle(id: 'c', number: '3', status: 'in_progress'),
        buildCycle(id: 'd', number: '4', status: 'awaiting_release'),
        buildCycle(id: 'e', number: '5', status: 'released'),
      ]),
    );
    final session = _Session();
    when(() => session.hasPermission(any())).thenReturn(true);
    if (GetIt.instance.isRegistered<SessionStore>()) {
      GetIt.instance.unregister<SessionStore>();
    }
    GetIt.instance.registerSingleton<SessionStore>(session);
  });

  tearDown(() => GetIt.instance.reset());

  Future<void> open(WidgetTester tester) async {
    // Wide enough for every filter chip (the row scrolls on a phone).
    tester.view.physicalSize = const Size(1800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      RepositoryProvider<CycleRepository>.value(
        value: repo,
        child: const CycleListScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('drafts have their own stage, so the stages add up to the total',
      (tester) async {
    await open(tester);
    expect(find.text('Tous les cycles (5)'), findsOneWidget);
    expect(find.text('En préparation (2)'), findsOneWidget);
    expect(find.text('En cours (1)'), findsOneWidget);
    expect(find.text('Attente Libération (1)'), findsOneWidget);
    expect(find.text('Conformes (1)'), findsOneWidget);
    // 2 + 1 + 1 + 1 = 5: nothing is missing from the overview.
    final pipeline = find.byKey(const Key('cycle-pipeline'));
    expect(pipeline, findsOneWidget);
    expect(find.descendant(of: pipeline, matching: find.text('Préparation')), findsOneWidget);
  });

  testWidgets('tapping "En préparation" lists exactly the draft cycles',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('En préparation (2)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cycle #1'), findsOneWidget);
    expect(find.textContaining('Cycle #2'), findsOneWidget);
    expect(find.textContaining('Cycle #3'), findsNothing);
    expect(find.textContaining('Cycle #5'), findsNothing);
  });
}
