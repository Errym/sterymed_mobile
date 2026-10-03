// Brief §9: the waiting-for-placement priority screen. The 0-7 / 8-14 / 15+
// buckets are counted by the SERVER over the whole waiting set and the bucket
// filter is applied by the server, so they stay right beyond page 1.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_summary_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/repositories/prosthetic_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/screens/prosthetic_waiting_placement_screen.dart';
import 'package:steriymed_mobile/shared/widgets/cards/kpi_card.dart';

import '../fixtures/prosthetic_case_fixture.dart';
import '../helpers/pump_app.dart';

class MockProstheticRepository extends Mock implements ProstheticRepository {}

class MockSessionStore extends Mock implements SessionStore {}

void main() {
  late MockProstheticRepository repo;

  setUp(() {
    // Each row carries its quick actions, so it is taller than a bare tile:
    // use a tall screen so the rows under test are all built.
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(800, 3000);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
    repo = MockProstheticRepository();
    if (GetIt.instance.isRegistered<ProstheticRepository>()) {
      GetIt.instance.unregister<ProstheticRepository>();
    }
    GetIt.instance.registerSingleton<ProstheticRepository>(repo);
    final session = MockSessionStore();
    when(() => session.hasPermission(any())).thenReturn(true);
    if (GetIt.instance.isRegistered<SessionStore>()) {
      GetIt.instance.unregister<SessionStore>();
    }
    GetIt.instance.registerSingleton<SessionStore>(session);
  });

  tearDown(() {
    GetIt.instance.unregister<ProstheticRepository>();
    GetIt.instance.unregister<SessionStore>();
  });

  final fresh = buildProstheticCase(
    id: 'fresh',
    patientReference: 'PAT-FRESH',
    daysWaitingForPlacement: 5,
  );
  final medium = buildProstheticCase(
    id: 'medium',
    patientReference: 'PAT-MEDIUM',
    daysWaitingForPlacement: 10,
  );
  final urgent = buildProstheticCase(
    id: 'urgent',
    patientReference: 'PAT-URGENT',
    daysWaitingForPlacement: 20,
  );

  // Stands in for the server: it filters by `aging` itself.
  void stubServer({ProstheticSummaryData? summary}) {
    when(() => repo.waitingForPlacement(
          cursor: any(named: 'cursor'),
          aging: any(named: 'aging'),
        )).thenAnswer((inv) async {
      final aging = inv.namedArguments[#aging] as String?;
      return CursorPage(
        items: switch (aging) {
          'fresh' => [fresh],
          'medium' => [medium],
          'urgent' => [urgent],
          _ => [fresh, medium, urgent],
        },
      );
    });
    when(() => repo.summary(scope: any(named: 'scope'))).thenAnswer(
      (_) async =>
          summary ??
          const ProstheticSummaryData(total: 3, fresh: 1, medium: 1, urgent: 1),
    );
  }

  // The value shown by the KpiCard whose label matches [label].
  String kpiValue(WidgetTester tester, String label) {
    final card = find.ancestor(
      of: find.text(label),
      matching: find.byType(KpiCard),
    );
    expect(card, findsOneWidget);
    final texts = tester
        .widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))
        .toList();
    // KpiCard renders exactly two Text widgets: the label then the value.
    return texts.firstWhere((t) => t.data != label).data!;
  }

  testWidgets('summary header shows one case in each aging band (1/1/1)',
      (tester) async {
    stubServer();

    await pumpApp(tester, const ProstheticWaitingPlacementScreen());
    await tester.pumpAndSettle();

    expect(find.byType(KpiCard), findsNWidgets(3));
    expect(kpiValue(tester, '0-7 jours'), '1');
    expect(kpiValue(tester, '8-14 jours'), '1');
    expect(kpiValue(tester, '15+ jours'), '1');
    expect(find.text('PAT-FRESH'), findsOneWidget);
    expect(find.text('PAT-MEDIUM'), findsOneWidget);
    expect(find.text('PAT-URGENT'), findsOneWidget);
  });

  testWidgets('the buckets are the server counts, not the loaded page',
      (tester) async {
    // 150 waiting cases; the page on screen holds only three of them.
    stubServer(
      summary: const ProstheticSummaryData(
        total: 150,
        fresh: 70,
        medium: 50,
        urgent: 30,
      ),
    );

    await pumpApp(tester, const ProstheticWaitingPlacementScreen());
    await tester.pumpAndSettle();

    expect(kpiValue(tester, '0-7 jours'), '70');
    expect(kpiValue(tester, '8-14 jours'), '50');
    expect(kpiValue(tester, '15+ jours'), '30');
    expect(find.text('150 dossiers en attente'), findsOneWidget);
  });

  testWidgets('tapping "15+ jours" asks the server for that bucket only',
      (tester) async {
    stubServer();

    await pumpApp(tester, const ProstheticWaitingPlacementScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('15+ jours'));
    await tester.pumpAndSettle();

    verify(() => repo.waitingForPlacement(
          cursor: any(named: 'cursor'),
          aging: 'urgent',
        )).called(1);
    expect(find.text('PAT-URGENT'), findsOneWidget);
    expect(find.text('PAT-FRESH'), findsNothing);
    expect(find.text('PAT-MEDIUM'), findsNothing);
    expect(find.text('Filtré : 15+ jours'), findsOneWidget);
    // The counts are the whole set's, unchanged by the filter.
    expect(kpiValue(tester, '0-7 jours'), '1');

    await tester.tap(find.text('Effacer'));
    await tester.pumpAndSettle();

    expect(find.text('Filtré : 15+ jours'), findsNothing);
    expect(find.text('PAT-FRESH'), findsOneWidget);
    expect(find.text('PAT-MEDIUM'), findsOneWidget);
    expect(find.text('PAT-URGENT'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
