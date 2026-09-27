// Task 2 (test coverage completion). Was an empty stub. Covers the "brief
// page 9" waiting-for-placement priority screen: load, empty state, error
// + retry, and load-more pagination — all real repository calls via GetIt
// (this screen resolves ProstheticRepository directly, not via the
// `provider` package).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/core/theme/tokens.dart';
import 'package:steriymed_mobile/features/prosthetic/data/repositories/prosthetic_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/screens/prosthetic_waiting_placement_screen.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/widgets/prosthetic_case_tile.dart';
import 'package:steriymed_mobile/shared/widgets/badges/aging_badge.dart';

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

  testWidgets('renders each waiting case with its patient reference',
      (tester) async {
    when(() => repo.waitingForPlacement()).thenAnswer(
      (_) async => CursorPage(
        items: [
          buildProstheticCase(id: 'c1', patientReference: 'PAT-000001'),
          buildProstheticCase(id: 'c2', patientReference: 'PAT-000002'),
        ],
      ),
    );

    await pumpApp(tester, const ProstheticWaitingPlacementScreen());
    await tester.pumpAndSettle();

    expect(find.text('PAT-000001'), findsOneWidget);
    expect(find.text('PAT-000002'), findsOneWidget);
  });

  testWidgets(
    'shows the empty state when no case is waiting for placement',
    (tester) async {
      when(() => repo.waitingForPlacement())
          .thenAnswer((_) async => const CursorPage(items: []));

      await pumpApp(tester, const ProstheticWaitingPlacementScreen());
      await tester.pumpAndSettle();

      expect(find.text('Aucun dossier en attente'), findsOneWidget);
    },
  );

  testWidgets('shows the real error message and retries on demand',
      (tester) async {
    when(() => repo.waitingForPlacement()).thenThrow(
      const ApiException(code: 'internal_error', message: 'Erreur serveur.'),
    );

    await pumpApp(tester, const ProstheticWaitingPlacementScreen());
    await tester.pumpAndSettle();

    expect(find.text('Erreur serveur.'), findsOneWidget);

    when(() => repo.waitingForPlacement()).thenAnswer(
      (_) async => CursorPage(
        items: [buildProstheticCase(id: 'c1', patientReference: 'PAT-000001')],
      ),
    );
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.text('PAT-000001'), findsOneWidget);
    verify(() => repo.waitingForPlacement()).called(2);
  });

  testWidgets('loading more appends the next page using the returned cursor',
      (tester) async {
    // CursorPaginatedList triggers onLoadMore from a real ScrollController
    // listener at (maxScrollExtent - 200) — needs enough items to actually
    // overflow the viewport, or there is nothing to scroll and the
    // threshold never fires.
    final firstPage = [
      for (var i = 0; i < 20; i++)
        buildProstheticCase(id: 'c$i', patientReference: 'PAT-$i'),
    ];
    when(() => repo.waitingForPlacement()).thenAnswer(
      (_) async => CursorPage(items: firstPage, nextCursor: 'cursor-2'),
    );
    when(() => repo.waitingForPlacement(cursor: 'cursor-2')).thenAnswer(
      (_) async => CursorPage(
        items: [buildProstheticCase(id: 'c-next', patientReference: 'PAT-NEXT')],
      ),
    );

    await pumpApp(tester, const ProstheticWaitingPlacementScreen());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable), const Offset(0, -5000));
    await tester.pumpAndSettle();

    expect(find.text('PAT-NEXT'), findsOneWidget);
    verify(() => repo.waitingForPlacement(cursor: 'cursor-2')).called(1);
  });

  group('AgingBadge tone by days waiting for placement', () {
    Color badgeTextColor(WidgetTester tester, String patientReference) {
      final tile = find.ancestor(
        of: find.text(patientReference),
        matching: find.byType(ProstheticCaseTile),
      );
      expect(tile, findsOneWidget);
      final badge = find.descendant(
        of: tile,
        matching: find.byType(AgingBadge),
      );
      expect(badge, findsOneWidget);
      final text = tester.widget<Text>(
        find.descendant(of: badge, matching: find.byType(Text)),
      );
      return text.style!.color!;
    }

    testWidgets(
      'fresh (5 days) is green, medium (10 days) is amber, urgent (20 '
      'days) is red',
      (tester) async {
        when(() => repo.waitingForPlacement()).thenAnswer(
          (_) async => CursorPage(items: [
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
          ]),
        );

        await pumpApp(tester, const ProstheticWaitingPlacementScreen());
        await tester.pumpAndSettle();

        expect(
          badgeTextColor(tester, 'PAT-FRESH'),
          AppColors.agingFresh,
          reason: '5 days is within the 0-7 day "fresh" band',
        );
        expect(
          badgeTextColor(tester, 'PAT-MEDIUM'),
          AppColors.agingMedium,
          reason: '10 days is within the 8-14 day "medium" band',
        );
        expect(
          badgeTextColor(tester, 'PAT-URGENT'),
          AppColors.agingUrgent,
          reason: '20 days is past the 14-day "urgent" threshold',
        );
      },
    );
  });
}
