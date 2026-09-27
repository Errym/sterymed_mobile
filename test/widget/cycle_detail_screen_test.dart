// Task 2 (test coverage completion). Was an empty stub. CycleDetailScreen
// is large (info card, timeline, notes, items, control tests, attachments,
// release, labels, one status-dependent action button) — this test covers
// the parts bloc-level tests don't already: rendering wiring, permission
// gating on the action button, and that a user action reaches the real
// repository with the right payload. Transition/list bloc *internals*
// (retry logic, error mapping) are already covered by
// cycle_transition_bloc_test.dart and cycle_list_bloc_test.dart — not
// re-tested here.
//
// Uses bounded pump() loops instead of pumpAndSettle(): _NotesSection opens
// a real CycleNotesCache Hive box directly in initState (it isn't
// injectable — lib/features/cycles/data/local/cycle_notes_cache.dart), and
// its own small inline CircularProgressIndicator never clears inside
// flutter_test's binding even though the exact same Hive call resolves
// fine in a plain (non-widget) test — a flutter_test/dart:io interaction,
// not a real app bug (confirmed by isolating CycleNotesCache.get() in a
// plain `test()`, where it resolves immediately). Since that indeterminate
// spinner keeps scheduling frames forever, pumpAndSettle() never returns.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/cycles/data/models/cycle_data.dart';
import 'package:steriymed_mobile/features/cycles/data/models/cycle_item_data.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/cycle_repository.dart';
import 'package:steriymed_mobile/features/cycles/presentation/screens/cycle_detail_screen.dart';
import 'package:steriymed_mobile/features/dlu/data/repositories/dlu_repository.dart';

import '../helpers/pump_app.dart';

// CycleDetailScreen's own Blocs resolve CycleRepository via the `provider`
// package's `context.read()` (wired app-wide by a RepositoryProvider in
// app.dart), while _LabelsSection and the item/attachment actions resolve
// it via `getIt<CycleRepository>()` directly — both paths need the mock.
Future<void> _pumpScreen(
  WidgetTester tester,
  CycleRepository repo, {
  String cycleId = 'cycle-1',
}) {
  return pumpApp(
    tester,
    RepositoryProvider<CycleRepository>.value(
      value: repo,
      child: CycleDetailScreen(cycleId: cycleId),
    ),
  );
}

/// Bounded settle — see the file header for why pumpAndSettle() can't be
/// used on this screen.
Future<void> _settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class MockSessionStore extends Mock implements SessionStore {}

class MockCycleRepository extends Mock implements CycleRepository {}

class MockDluRepository extends Mock implements DluRepository {}

CycleData _buildCycle({String status = 'created'}) => CycleData(
      id: 'cycle-1',
      number: 'CT-042',
      status: status,
      deviceId: 'device-1',
      deviceName: 'Melag Vacuklav',
      createdAt: DateTime(2026, 9, 20, 8, 0),
    );

void main() {
  late MockSessionStore session;
  late MockCycleRepository repo;
  late MockDluRepository dluRepo;
  late Directory tempDir;

  // Pre-open the box outside the widget-test zone: opening it fresh *inside*
  // testWidgets leaves a real, uncontrolled dart:io Timer pending when the
  // widget tree is disposed before that real I/O settles (flutter_test's
  // fake-time pump doesn't drive real disk I/O), which trips flutter_test's
  // "Timer still pending" invariant check. Once already open, Hive's
  // openBox() returns the cached instance synchronously, so
  // CycleNotesCache's own openBox() call inside _NotesSection.initState()
  // never touches real I/O during the test.
  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('cycle_detail_screen_test');
    Hive.init(tempDir.path);
    await Hive.openBox('steriymed.cycle_notes');
  });

  tearDownAll(() async {
    await Hive.box('steriymed.cycle_notes').close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() {
    session = MockSessionStore();
    repo = MockCycleRepository();
    dluRepo = MockDluRepository();

    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => repo.show(any())).thenAnswer((_) async => _buildCycle());
    when(() => repo.listItems(any())).thenAnswer((_) async => []);
    when(() => repo.listControlTests(any())).thenAnswer((_) async => []);
    when(() => repo.listAttachments(any())).thenAnswer((_) async => []);
    when(() => repo.countLabels(any())).thenAnswer((_) async => 0);

    if (GetIt.instance.isRegistered<SessionStore>()) {
      GetIt.instance.unregister<SessionStore>();
    }
    if (GetIt.instance.isRegistered<CycleRepository>()) {
      GetIt.instance.unregister<CycleRepository>();
    }
    if (GetIt.instance.isRegistered<DluRepository>()) {
      GetIt.instance.unregister<DluRepository>();
    }
    GetIt.instance.registerSingleton<SessionStore>(session);
    GetIt.instance.registerSingleton<CycleRepository>(repo);
    GetIt.instance.registerSingleton<DluRepository>(dluRepo);
  });

  tearDown(() {
    GetIt.instance.unregister<SessionStore>();
    GetIt.instance.unregister<CycleRepository>();
    GetIt.instance.unregister<DluRepository>();
  });

  testWidgets('renders the cycle number and device once loaded',
      (tester) async {
    await _pumpScreen(tester, repo);
    await _settle(tester);

    expect(find.text('Cycle CT-042'), findsOneWidget);
    expect(find.text('Melag Vacuklav'), findsOneWidget);
  });

  testWidgets(
    'a user without cycles.manage sees a read-only banner instead of the '
    'start action, for a cycle that is otherwise actionable',
    (tester) async {
      when(() => session.hasPermission('cycles.manage')).thenReturn(false);
      when(() => session.hasPermission('cycles.release')).thenReturn(false);

      await _pumpScreen(tester, repo);
      await _settle(tester);

      // The action-button area is the last list item — scroll straight to
      // the bottom rather than incrementally searching for it.
      await tester.drag(find.byType(Scrollable), const Offset(0, -3000));
      await _settle(tester);

      expect(find.text('Démarrer le cycle'), findsNothing);
      expect(find.textContaining('lecture seule'), findsOneWidget);
    },
  );

  testWidgets(
    'starting a cycle calls CycleRepository.start and shows a success '
    'snackbar after confirming',
    (tester) async {
      when(() => repo.start(any())).thenAnswer(
        (_) async => _buildCycle(status: 'in_progress'),
      );

      await _pumpScreen(tester, repo);
      await _settle(tester);

      await tester.drag(find.byType(Scrollable), const Offset(0, -3000));
      await _settle(tester);
      await tester.tap(find.text('Démarrer le cycle'));
      await _settle(tester);

      // Confirmation dialog.
      expect(find.text('Démarrer le cycle ?'), findsOneWidget);
      await tester.tap(find.text('Démarrer'));
      await _settle(tester);

      verify(() => repo.start('cycle-1')).called(1);
      expect(find.text('Cycle mis à jour.'), findsOneWidget);
    },
  );

  testWidgets(
    'adding an instrument calls CycleRepository.addItem with the entered '
    'description and refreshes the list',
    (tester) async {
      when(() => repo.addItem(any(), any())).thenAnswer(
        (_) async => CycleItemData(
          id: 'item-1',
          cycleId: 'cycle-1',
          description: 'Cassette chirurgicale',
          createdAt: DateTime(2026, 9, 20, 9, 0),
        ),
      );

      await _pumpScreen(tester, repo);
      await _settle(tester);

      // SectionHeader renders its title upper-cased ("INSTRUMENTS (0)").
      // Find the add icon precisely by its own section header's Row rather
      // than `.first`, since the (disabled, for this status) Control Tests
      // section has an identical add_circle_outline icon right after it.
      await tester.drag(find.byType(Scrollable), const Offset(0, -450));
      await _settle(tester);

      final instrumentsRow = find.ancestor(
        of: find.textContaining('INSTRUMENTS ('),
        matching: find.byType(Row),
      );
      expect(instrumentsRow, findsOneWidget);
      final addInstrumentIcon = find.descendant(
        of: instrumentsRow,
        matching: find.byIcon(Icons.add_circle_outline),
      );
      await tester.ensureVisible(addInstrumentIcon);
      await _settle(tester);
      await tester.tap(addInstrumentIcon);
      await _settle(tester);

      expect(find.text('Ajouter un instrument'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Cassette chirurgicale');
      await tester.tap(find.text('Ajouter'));
      await _settle(tester);

      final captured =
          verify(() => repo.addItem('cycle-1', captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['description'], 'Cassette chirurgicale');
      expect(find.text('Instrument ajouté.'), findsOneWidget);
      // Refreshed — listItems (called once on initial load) called again.
      verify(() => repo.listItems('cycle-1')).called(2);
    },
  );
}
