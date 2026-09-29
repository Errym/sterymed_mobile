// TASK B/C verification: the "brief page 9" waiting-for-placement priority
// screen's aging summary. Mocks ProstheticRepository (resolved directly via
// GetIt by the screen) to return one case in each aging band (5 / 10 / 20
// days) and asserts the 3 KpiCard counts plus the client-side "15+ jours"
// filter.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/features/prosthetic/data/repositories/prosthetic_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/screens/prosthetic_waiting_placement_screen.dart';
import 'package:steriymed_mobile/shared/widgets/cards/kpi_card.dart';

import '../fixtures/prosthetic_case_fixture.dart';
import '../helpers/pump_app.dart';

class MockProstheticRepository extends Mock implements ProstheticRepository {}

void main() {
  late MockProstheticRepository repo;

  setUp(() {
    repo = MockProstheticRepository();
    if (GetIt.instance.isRegistered<ProstheticRepository>()) {
      GetIt.instance.unregister<ProstheticRepository>();
    }
    GetIt.instance.registerSingleton<ProstheticRepository>(repo);
  });

  tearDown(() {
    GetIt.instance.unregister<ProstheticRepository>();
  });

  // One case per aging band: 5 days (fresh), 10 days (medium), 20 days (urgent).
  void stubThreeBands() {
    when(() => repo.waitingForPlacement()).thenAnswer(
      (_) async => CursorPage(
        items: [
          buildProstheticCase(
            id: 'fresh',
            patientReference: 'PAT-FRESH',
            daysWaitingForPlacement: 5,
          ),
          buildProstheticCase(
            id: 'medium',
            patientReference: 'PAT-MEDIUM',
            daysWaitingForPlacement: 10,
          ),
          buildProstheticCase(
            id: 'urgent',
            patientReference: 'PAT-URGENT',
            daysWaitingForPlacement: 20,
          ),
        ],
      ),
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
    stubThreeBands();

    await pumpApp(tester, const ProstheticWaitingPlacementScreen());
    await tester.pumpAndSettle();

    expect(find.byType(KpiCard), findsNWidgets(3));
    expect(kpiValue(tester, '0-7 jours'), '1');
    expect(kpiValue(tester, '8-14 jours'), '1');
    expect(kpiValue(tester, '15+ jours'), '1');

    // All three tiles are visible before any filter is applied.
    expect(find.text('PAT-FRESH'), findsOneWidget);
    expect(find.text('PAT-MEDIUM'), findsOneWidget);
    expect(find.text('PAT-URGENT'), findsOneWidget);
  });

  testWidgets('tapping the "15+ jours" card filters to only the urgent case',
      (tester) async {
    stubThreeBands();

    await pumpApp(tester, const ProstheticWaitingPlacementScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('15+ jours'));
    await tester.pumpAndSettle();

    // Only the 20-day case remains in the list.
    expect(find.text('PAT-URGENT'), findsOneWidget);
    expect(find.text('PAT-FRESH'), findsNothing);
    expect(find.text('PAT-MEDIUM'), findsNothing);

    // The active-filter chip is shown, and the counts are unchanged (they
    // reflect the full loaded page, not the filtered view).
    expect(find.text('Filtré : 15+ jours'), findsOneWidget);
    expect(kpiValue(tester, '0-7 jours'), '1');
    expect(kpiValue(tester, '15+ jours'), '1');

    // Clearing the filter via the chip restores every case.
// Clearing the filter via the "Effacer" link restores every case.
    await tester.tap(find.text('Effacer'));
    await tester.pumpAndSettle();

    expect(find.text('Filtré : 15+ jours'), findsNothing);
    expect(find.text('PAT-FRESH'), findsOneWidget);
    expect(find.text('PAT-MEDIUM'), findsOneWidget);
    expect(find.text('PAT-URGENT'), findsOneWidget);
  });
}
