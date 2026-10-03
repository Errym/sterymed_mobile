// TASK verification: the offline "queued vs synced" feedback distinction for
// the three stock write screens. Each screen resolves StockRepository from
// GetIt and, on success, shows either the plain success SnackBar (online) or
// the "Enregistré localement…" queued SnackBar + "Voir la file" action
// (offline outbox result, StockMovementData.isQueued == true). A GoRouter
// harness is used because the screens call context.pop() after showing the
// SnackBar (the go_router extension needs a real router + back stack).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/router/routes.dart';
import 'package:steriymed_mobile/di/di.dart';
import 'package:steriymed_mobile/features/stock/data/models/stock_movement_data.dart';
import 'package:steriymed_mobile/features/stock/data/models/stock_level_data.dart';
import 'package:steriymed_mobile/features/stock/data/models/stock_option.dart';
import 'package:steriymed_mobile/features/stock/data/repositories/stock_repository.dart';
import 'package:steriymed_mobile/features/stock/presentation/screens/stock_adjust_screen.dart';
import 'package:steriymed_mobile/features/stock/presentation/screens/stock_issue_screen.dart';
import 'package:steriymed_mobile/features/stock/presentation/screens/stock_transfer_screen.dart';

import '../helpers/pump_app.dart';

class MockStockRepository extends Mock implements StockRepository {}

const _queuedMessage = 'Enregistré localement. Synchronisation en attente.';

StockMovementData _movement({required bool isQueued}) => StockMovementData(
      id: 'm-1',
      kind: 'issue',
      batchId: 'b-1',
      locationId: 'l-1',
      qty: 2,
      createdAt: DateTime(2026, 9, 20),
      isQueued: isQueued,
    );

const _row = StockLevelData(
  id: 's-1',
  productId: 'p-1',
  productName: 'Gants',
  reference: 'GN-1',
  unit: 'boîte',
  locationId: 'l-1',
  locationName: 'Réserve',
  qty: 10,
  minThreshold: 2,
  batchId: 'b-1',
  batchNumber: 'A1',
);

void main() {
  late MockStockRepository repo;

  setUp(() {
    repo = MockStockRepository();
    when(() => repo.listSources()).thenAnswer((_) async => [_row]);
    when(() => repo.listOptions(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer(
      (_) async => (
        batches: [const StockOption(id: 'b-1', label: 'Lot A')],
        locations: [
          const StockOption(id: 'l-1', label: 'Réserve'),
          const StockOption(id: 'l-2', label: 'Bloc'),
        ],
      ),
    );
    if (getIt.isRegistered<StockRepository>()) {
      getIt.unregister<StockRepository>();
    }
    getIt.registerSingleton<StockRepository>(repo);
  });

  tearDown(() {
    getIt.unregister<StockRepository>();
  });

  // Screen pushed under a home route so context.pop() has somewhere to land.
  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    final router = GoRouter(
      initialLocation: '/home/action',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('HOME')),
          routes: [
            GoRoute(path: 'action', builder: (_, __) => screen),
          ],
        ),
        GoRoute(
          path: Routes.sync,
          builder: (_, __) => const Scaffold(body: Text('SYNC QUEUE')),
        ),
      ],
    );
    await pumpAppWidget(tester, MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  group('StockIssueScreen', () {
    testWidgets('online result shows the plain success message',
        (tester) async {
      when(() => repo.issue(
            batchId: any(named: 'batchId'),
            locationId: any(named: 'locationId'),
            qty: any(named: 'qty'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async => _movement(isQueued: false));

      await pumpScreen(tester, const StockIssueScreen(batchId: 'b-1', locationId: 'l-1'));
      await tester.tap(find.text('Enregistrer la sortie'));
      await tester.pumpAndSettle();

      expect(find.text('Sortie enregistrée.'), findsOneWidget);
      expect(find.text(_queuedMessage), findsNothing);
    });

    testWidgets('queued result shows the queued message and "Voir la file"',
        (tester) async {
      when(() => repo.issue(
            batchId: any(named: 'batchId'),
            locationId: any(named: 'locationId'),
            qty: any(named: 'qty'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async => _movement(isQueued: true));

      await pumpScreen(tester, const StockIssueScreen(batchId: 'b-1', locationId: 'l-1'));
      await tester.tap(find.text('Enregistrer la sortie'));
      await tester.pumpAndSettle();

      expect(find.text(_queuedMessage), findsOneWidget);
      expect(find.text('Voir la file'), findsOneWidget);
      expect(find.text('Sortie enregistrée.'), findsNothing);
    });
  });

  group('StockAdjustScreen', () {
    testWidgets('queued result shows the queued message', (tester) async {
      when(() => repo.adjust(
            batchId: any(named: 'batchId'),
            locationId: any(named: 'locationId'),
            qty: any(named: 'qty'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async => _movement(isQueued: true));

      await pumpScreen(tester, const StockAdjustScreen(batchId: 'b-1', locationId: 'l-1'));
      await tester.scrollUntilVisible(
        find.text('Motif (obligatoire) *'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextFormField).last, 'Inventaire');
      await tester.tap(find.text('Enregistrer l\'ajustement'));
      await tester.pumpAndSettle();

      expect(find.text(_queuedMessage), findsOneWidget);
      expect(find.text('Voir la file'), findsOneWidget);
    });

    testWidgets('online result shows the plain success message',
        (tester) async {
      when(() => repo.adjust(
            batchId: any(named: 'batchId'),
            locationId: any(named: 'locationId'),
            qty: any(named: 'qty'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async => _movement(isQueued: false));

      await pumpScreen(tester, const StockAdjustScreen(batchId: 'b-1', locationId: 'l-1'));
      await tester.scrollUntilVisible(
        find.text('Motif (obligatoire) *'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextFormField).last, 'Inventaire');
      await tester.tap(find.text('Enregistrer l\'ajustement'));
      await tester.pumpAndSettle();

      expect(find.text('Ajustement enregistré.'), findsOneWidget);
      expect(find.text(_queuedMessage), findsNothing);
    });
  });

  group('StockTransferScreen', () {
    testWidgets('queued result shows the queued message', (tester) async {
      when(() => repo.transfer(
            batchId: any(named: 'batchId'),
            fromLocationId: any(named: 'fromLocationId'),
            toLocationId: any(named: 'toLocationId'),
            qty: any(named: 'qty'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async => _movement(isQueued: true));

      await pumpScreen(tester, const StockTransferScreen(batchId: 'b-1', locationId: 'l-1'));
      await tester.tap(find.byKey(const ValueKey('destination')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bloc').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer le transfert'));
      await tester.pumpAndSettle();

      expect(find.text(_queuedMessage), findsOneWidget);
      expect(find.text('Voir la file'), findsOneWidget);
    });
  });
}
