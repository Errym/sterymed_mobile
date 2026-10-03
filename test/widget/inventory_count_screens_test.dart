// Inventory counts ("inventaire") and the product code lookup: the screens
// render the server's answer, offer the count/close/cancel actions only to
// whoever holds inventory.manage, and show a failure instead of hiding it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/stock/data/models/code_lookup.dart';
import 'package:steriymed_mobile/features/stock/data/models/inventory_count_data.dart';
import 'package:steriymed_mobile/features/stock/data/repositories/inventory_count_repository.dart';
import 'package:steriymed_mobile/features/stock/data/repositories/stock_repository.dart';
import 'package:steriymed_mobile/features/stock/presentation/screens/code_lookup_screen.dart';
import 'package:steriymed_mobile/features/stock/presentation/screens/inventory_count_detail_screen.dart';
import 'package:steriymed_mobile/features/stock/presentation/screens/inventory_count_list_screen.dart';

import '../helpers/pump_app.dart';

class MockSessionStore extends Mock implements SessionStore {}

class MockInventoryRepo extends Mock implements InventoryCountRepository {}

class MockStockRepo extends Mock implements StockRepository {}

const _summary = InventoryCountSummary(
  id: 'c-1',
  locationId: 'l-1',
  locationName: 'Réserve',
  status: 'open',
  openedByName: 'Awa',
  linesCount: 1,
  adjustmentsCount: 0,
);

InventoryCountDetail _detail({
  InventoryCountSummary summary = _summary,
  List<InventoryUncounted> uncounted = const [
    InventoryUncounted(
      batchId: 'b-2',
      batchNumber: 'L-200',
      productName: 'Compresses',
      batchStatus: 'active',
      systemQty: 12,
    ),
  ],
}) => InventoryCountDetail(
  summary: summary,
  lines: const [
    InventoryCountLine(
      batchId: 'b-1',
      batchNumber: 'L-100',
      productName: 'Gants',
      batchStatus: 'active',
      countedQty: 8,
      expectedQty: 10,
      variance: -2,
      countedByName: 'Awa',
    ),
  ],
  uncounted: uncounted,
);

void main() {
  late MockSessionStore session;
  late MockInventoryRepo repo;
  final getIt = GetIt.instance;

  setUp(() async {
    await getIt.reset();
    session = MockSessionStore();
    repo = MockInventoryRepo();
    when(() => session.hasPermission(any())).thenReturn(true);
    getIt.registerSingleton<SessionStore>(session);
    getIt.registerSingleton<InventoryCountRepository>(repo);
  });

  tearDown(() async => getIt.reset());

  group('InventoryCountDetailScreen', () {
    testWidgets('shows uncounted and counted lots with the variance', (
      tester,
    ) async {
      when(() => repo.show('c-1')).thenAnswer((_) async => _detail());

      await pumpApp(tester, const InventoryCountDetailScreen(countId: 'c-1'));
      await tester.pumpAndSettle();

      expect(find.text('Compresses'), findsOneWidget);
      expect(find.text('Gants'), findsOneWidget);
      expect(find.text('-2'), findsOneWidget);
      expect(find.text('Terminer l\'inventaire'), findsOneWidget);
    });

    testWidgets('a viewer sees the session but no counting actions', (
      tester,
    ) async {
      when(() => session.hasPermission('inventory.manage')).thenReturn(false);
      when(() => repo.show('c-1')).thenAnswer((_) async => _detail());

      await pumpApp(tester, const InventoryCountDetailScreen(countId: 'c-1'));
      await tester.pumpAndSettle();

      expect(find.text('Compresses'), findsOneWidget);
      expect(find.text('Compter'), findsNothing);
      expect(find.text('Terminer l\'inventaire'), findsNothing);
      expect(find.text('Annuler l\'inventaire'), findsNothing);
    });

    testWidgets('counting a lot sends the typed quantity, zero included', (
      tester,
    ) async {
      when(() => repo.show('c-1')).thenAnswer((_) async => _detail());
      when(
        () => repo.recordLine(
          countId: any(named: 'countId'),
          batchId: any(named: 'batchId'),
          countedQty: any(named: 'countedQty'),
        ),
      ).thenAnswer(
        (_) async => const InventoryCountLine(
          batchId: 'b-2',
          batchNumber: 'L-200',
          productName: 'Compresses',
          batchStatus: 'active',
          countedQty: 0,
          expectedQty: 12,
          variance: -12,
          countedByName: 'Awa',
        ),
      );

      await pumpApp(tester, const InventoryCountDetailScreen(countId: 'c-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('count_b-2')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('count_qty')), '0');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      verify(
        () => repo.recordLine(countId: 'c-1', batchId: 'b-2', countedQty: 0),
      ).called(1);
    });

    testWidgets('a negative or empty quantity is refused before sending', (
      tester,
    ) async {
      when(() => repo.show('c-1')).thenAnswer((_) async => _detail());

      await pumpApp(tester, const InventoryCountDetailScreen(countId: 'c-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('count_b-2')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('count_qty')), '-3');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('nombre entier'), findsOneWidget);
      verifyNever(
        () => repo.recordLine(
          countId: any(named: 'countId'),
          batchId: any(named: 'batchId'),
          countedQty: any(named: 'countedQty'),
        ),
      );
    });

    testWidgets('closing with uncounted lots acknowledges them explicitly', (
      tester,
    ) async {
      when(() => repo.show('c-1')).thenAnswer((_) async => _detail());
      when(
        () => repo.close(
          any(),
          acknowledgeUncounted: any(named: 'acknowledgeUncounted'),
        ),
      ).thenAnswer((_) async => _detail(uncounted: const []));

      await pumpApp(tester, const InventoryCountDetailScreen(countId: 'c-1'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Terminer l\'inventaire'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminer l\'inventaire'));
      await tester.pumpAndSettle();
      expect(find.textContaining('n\'ont pas été comptés'), findsOneWidget);
      await tester.tap(find.text('Terminer').last);
      await tester.pumpAndSettle();

      verify(() => repo.close('c-1', acknowledgeUncounted: true)).called(1);
    });

    testWidgets('a server refusal is shown in French, not swallowed', (
      tester,
    ) async {
      when(() => repo.show('c-1')).thenAnswer((_) async => _detail());
      when(
        () => repo.close(
          any(),
          acknowledgeUncounted: any(named: 'acknowledgeUncounted'),
        ),
      ).thenThrow(
        const ApiException(
          code: 'INVENTORY_COUNT_LINE_STALE',
          message: 'stale',
          statusCode: 409,
        ),
      );

      await pumpApp(tester, const InventoryCountDetailScreen(countId: 'c-1'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Terminer l\'inventaire'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminer l\'inventaire'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminer').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Recomptez-le'), findsOneWidget);
    });

    testWidgets('a closed session is read-only', (tester) async {
      when(() => repo.show('c-1')).thenAnswer(
        (_) async => _detail(
          summary: const InventoryCountSummary(
            id: 'c-1',
            locationId: 'l-1',
            locationName: 'Réserve',
            status: 'closed',
            openedByName: 'Awa',
            closedByName: 'Awa',
            linesCount: 1,
            adjustmentsCount: 1,
          ),
          uncounted: const [],
        ),
      );

      await pumpApp(tester, const InventoryCountDetailScreen(countId: 'c-1'));
      await tester.pumpAndSettle();

      expect(find.text('Terminé'), findsOneWidget);
      expect(find.text('Terminer l\'inventaire'), findsNothing);
      expect(find.text('Compter'), findsNothing);
    });
  });

  group('InventoryCountListScreen', () {
    testWidgets('lists sessions and hides "new" from a viewer', (tester) async {
      when(() => session.hasPermission('inventory.manage')).thenReturn(false);
      when(() => repo.list()).thenAnswer(
        (_) async => const CursorPage(items: [_summary]),
      );

      await pumpApp(tester, const InventoryCountListScreen());
      await tester.pumpAndSettle();

      expect(find.text('Réserve'), findsOneWidget);
      expect(find.text('En cours'), findsOneWidget);
      expect(find.text('Nouvel inventaire'), findsNothing);
    });

    testWidgets('empty list explains what an inventory is', (tester) async {
      when(() => repo.list()).thenAnswer((_) async => const CursorPage(items: []));

      await pumpApp(tester, const InventoryCountListScreen());
      await tester.pumpAndSettle();

      expect(find.text('Aucun inventaire'), findsOneWidget);
      expect(find.text('Nouvel inventaire'), findsOneWidget);
    });

    testWidgets('a load failure offers a retry', (tester) async {
      when(() => repo.list()).thenThrow(
        const ApiException(code: 'NETWORK', message: 'x', statusCode: 0),
      );

      await pumpApp(tester, const InventoryCountListScreen());
      await tester.pumpAndSettle();

      expect(find.text('Réessayer'), findsOneWidget);
    });
  });

  group('CodeLookupScreen', () {
    late MockStockRepo stock;

    CodeLookup lookup({bool quarantined = false}) => CodeLookup(
      code: '3401',
      matchedBy: 'barcode',
      products: [
        LookupProduct(
          id: 'p-1',
          name: 'Gants',
          reference: 'GN-1',
          unit: 'boîte',
          minThreshold: 2,
          qtyOnHand: 10,
          batches: [
            LookupBatch(
              id: 'b-1',
              batchNumber: 'L-100',
              status: quarantined ? 'quarantined' : 'active',
              isExpired: false,
              qtyOnHand: 10,
              locations: const [
                LookupLocation(
                  locationId: 'l-1',
                  locationName: 'Réserve',
                  archived: false,
                  quantity: 10,
                ),
              ],
            ),
          ],
        ),
      ],
    );

    setUp(() {
      stock = MockStockRepo();
      getIt.registerSingleton<StockRepository>(stock);
    });

    Future<void> pump(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const CodeLookupScreen(code: '3401'),
          ),
        ],
      );
      await pumpAppWidget(tester, MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the product, its lot and where it is', (tester) async {
      when(() => stock.lookupCode('3401')).thenAnswer((_) async => lookup());

      await pump(tester);

      expect(find.text('Gants'), findsOneWidget);
      expect(find.textContaining('L-100'), findsOneWidget);
      expect(find.textContaining('Réserve'), findsOneWidget);
      expect(find.byTooltip('Sortie'), findsOneWidget);
      expect(find.byTooltip('Transfert'), findsOneWidget);
      expect(find.byTooltip('Ajustement'), findsOneWidget);
    });

    testWidgets('a quarantined lot offers no way out of stock', (tester) async {
      when(() => stock.lookupCode('3401')).thenAnswer(
        (_) async => lookup(quarantined: true),
      );

      await pump(tester);

      expect(find.text('Quarantaine'), findsOneWidget);
      expect(find.byTooltip('Sortie'), findsNothing);
      expect(find.byTooltip('Transfert'), findsNothing);
    });

    testWidgets('a viewer can read but not move stock', (tester) async {
      when(() => session.hasPermission('inventory.manage')).thenReturn(false);
      when(() => stock.lookupCode('3401')).thenAnswer((_) async => lookup());

      await pump(tester);

      expect(find.text('Gants'), findsOneWidget);
      expect(find.byTooltip('Sortie'), findsNothing);
    });

    testWidgets('an unknown code says so in French', (tester) async {
      when(() => stock.lookupCode('3401')).thenThrow(
        const ApiException(
          code: 'CODE_NOT_FOUND',
          message: 'nope',
          statusCode: 404,
        ),
      );

      await pump(tester);

      expect(
        find.text('Aucun produit ni lot ne correspond à ce code.'),
        findsOneWidget,
      );
    });
  });
}
