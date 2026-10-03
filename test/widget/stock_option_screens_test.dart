// The Stock option as each role meets it: the list, its chips and headline
// figures, the lot and product sheets, and the movement entry points that only
// a role allowed to manage stock may use.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/router/routes.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/stock/data/models/batch_data.dart';
import 'package:steriymed_mobile/features/stock/data/models/stock_level_data.dart';
import 'package:steriymed_mobile/features/stock/data/repositories/stock_repository.dart';
import 'package:steriymed_mobile/features/stock/presentation/screens/batch_list_screen.dart';
import 'package:steriymed_mobile/features/stock/presentation/screens/stock_level_list_screen.dart';
import 'package:steriymed_mobile/shared/widgets/layout/form_card.dart';

import '../helpers/pump_app.dart';

class _MockRepo extends Mock implements StockRepository {}

class _MockSession extends Mock implements SessionStore {}

String _day(int offset) {
  final d = DateTime.now().add(Duration(days: offset));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

StockLevelData _row(
  String id, {
  required String name,
  required int qty,
  int min = 10,
  int? expiresIn,
  String lot = 'LOT',
}) =>
    StockLevelData.fromJson({
      'id': id,
      'product_id': 'p-$id',
      'product_name': name,
      'product_reference': 'REF-$id',
      'product_unit': 'boîtes',
      'location_id': 'loc-1',
      'location_name': 'Réserve centrale',
      'batch_id': 'b-$id',
      'batch_number': '$lot-$id',
      'quantity': qty,
      'min_threshold': min,
      if (expiresIn != null) 'expiry_date': _day(expiresIn),
    });

void main() {
  late _MockRepo repo;
  late _MockSession session;

  final rows = [
    _row('ok', name: 'Gants nitrile', qty: 45),
    _row('low', name: 'Compresses stériles', qty: 3),
    _row('exp', name: 'Articaïne', qty: 20, expiresIn: -4),
  ];

  setUp(() {
    repo = _MockRepo();
    session = _MockSession();
    when(() => repo.listLevels(
          search: any(named: 'search'),
          forceRefresh: any(named: 'forceRefresh'),
          inStockOnly: any(named: 'inStockOnly'),
        )).thenAnswer((_) async => rows);
    when(() => session.hasPermission(any())).thenReturn(false);
    for (final t in [StockRepository, SessionStore]) {
      if (t == StockRepository && GetIt.I.isRegistered<StockRepository>()) {
        GetIt.I.unregister<StockRepository>();
      }
      if (t == SessionStore && GetIt.I.isRegistered<SessionStore>()) {
        GetIt.I.unregister<SessionStore>();
      }
    }
    GetIt.I.registerSingleton<StockRepository>(repo);
    GetIt.I.registerSingleton<SessionStore>(session);
  });

  tearDown(() {
    GetIt.I.unregister<StockRepository>();
    GetIt.I.unregister<SessionStore>();
  });

  void allow(Set<String> permissions) {
    when(() => session.hasPermission(any())).thenAnswer(
      (i) => permissions.contains(i.positionalArguments.first as String),
    );
  }

  /// A router with the stock tab and a stand-in for each form, so navigation
  /// can be asserted without building the real forms.
  Future<GoRouter> pumpStock(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: Routes.stock,
      routes: [
        GoRoute(path: Routes.stock, builder: (_, __) => home),
        GoRoute(path: Routes.batches, builder: (_, __) => home),
        GoRoute(
          path: Routes.stockIssue,
          builder: (_, s) => Scaffold(
            body: Text('ISSUE batch=${s.uri.queryParameters['batch']} '
                'loc=${s.uri.queryParameters['location']}'),
          ),
        ),
        GoRoute(
          path: Routes.stockTransfer,
          builder: (_, __) => const Scaffold(body: Text('TRANSFER FORM')),
        ),
        GoRoute(
          path: Routes.stockAdjust,
          builder: (_, __) => const Scaffold(body: Text('ADJUST FORM')),
        ),
        GoRoute(
          path: Routes.inventory,
          builder: (_, __) => const Scaffold(body: Text('INVENTORY LIST')),
        ),
        GoRoute(
          path: Routes.scanner,
          builder: (_, s) => Scaffold(
            body: Text('SCANNER mode=${s.uri.queryParameters['mode']}'),
          ),
        ),
        GoRoute(
          path: Routes.alerts,
          builder: (_, __) => const Scaffold(body: Text('ALERTS')),
        ),
      ],
    );
    await pumpAppWidget(tester, MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  group('stock list', () {
    testWidgets('shows the headline figures, chips with counts, and sorts by '
        'criticity', (tester) async {
      allow({'inventory.view', 'inventory.manage'});
      await pumpStock(tester, const StockLevelListScreen());

      expect(find.text('ÉTAT GLOBAL'), findsOneWidget);
      expect(find.text('RÉAPPRO URGENT'), findsOneWidget);
      // 1 healthy of 3 rows.
      expect(find.text('33 %'), findsOneWidget);
      expect(find.text('1 réf.'), findsOneWidget);
      expect(find.text('Tous (3)'), findsOneWidget);
      expect(find.text('Stock bas (1)'), findsOneWidget);
      expect(find.text('Périmés (1)'), findsOneWidget);
      expect(find.text('Tri : criticité'), findsOneWidget);

      // Expired first, then under the minimum, then the healthy row.
      final expired = tester.getTopLeft(find.text('Articaïne')).dy;
      final low = tester.getTopLeft(find.text('Compresses stériles')).dy;
      final fine = tester.getTopLeft(find.text('Gants nitrile')).dy;
      expect(expired, lessThan(low));
      expect(low, lessThan(fine));
    });

    testWidgets('a chip narrows the list and "no result" offers a way back',
        (tester) async {
      allow({'inventory.view'});
      await pumpStock(tester, const StockLevelListScreen());

      await tester.tap(find.text('Stock bas (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Compresses stériles'), findsOneWidget);
      expect(find.text('Gants nitrile'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Aucun résultat'), findsOneWidget);
      await tester.tap(find.text('Réinitialiser le filtre'));
      // The search is debounced: let it settle.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Aucun résultat'), findsNothing);
      expect(find.text('Gants nitrile'), findsOneWidget);
      final box = tester.widget<TextField>(find.byType(TextField));
      expect(box.controller!.text, isEmpty,
          reason: 'the search box is emptied too');
    });

    testWidgets('a role that cannot manage stock has no movement button and '
        'no row actions', (tester) async {
      allow({'inventory.view'});
      await pumpStock(tester, const StockLevelListScreen());

      expect(find.byKey(const Key('stock-new-movement')), findsNothing);

      await tester.tap(find.text('Gants nitrile'));
      await tester.pumpAndSettle();
      // The full detail is there...
      expect(find.text('Réserve centrale'), findsWidgets);
      expect(find.text('Référence'), findsOneWidget);
      // ...but no way to change anything.
      expect(find.text('ACTIONS SUR CETTE LIGNE'), findsNothing);
      expect(find.text('Sortie'), findsNothing);
    });

    testWidgets('a role that manages stock gets the movement menu',
        (tester) async {
      allow({'inventory.view', 'inventory.manage'});
      final router = await pumpStock(tester, const StockLevelListScreen());

      await tester.tap(find.byKey(const Key('stock-new-movement')));
      await tester.pumpAndSettle();
      expect(find.text('Sortie de stock'), findsOneWidget);
      expect(find.text('Transfert'), findsOneWidget);
      expect(find.text('Ajustement'), findsOneWidget);
      expect(find.text('Inventaire'), findsOneWidget);

      await tester.tap(find.text('Transfert'));
      await tester.pumpAndSettle();
      expect(find.text('TRANSFER FORM'), findsOneWidget);
      // Opened on top of the stock tab: there is a way back.
      expect(router.canPop(), isTrue);
    });

    testWidgets('a row opens its detail and starts a movement on that very '
        'lot and place', (tester) async {
      allow({'inventory.view', 'inventory.manage'});
      final router = await pumpStock(tester, const StockLevelListScreen());

      await tester.tap(find.text('Gants nitrile'));
      await tester.pumpAndSettle();
      expect(find.text('ACTIONS SUR CETTE LIGNE'), findsOneWidget);

      await tester.tap(find.text('Sortie'));
      await tester.pumpAndSettle();
      expect(find.text('ISSUE batch=b-ok loc=loc-1'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Gants nitrile'), findsOneWidget);
    });

    testWidgets('an expired row offers an exit (to throw it away) but a '
        'quarantined one does not', (tester) async {
      allow({'inventory.view', 'inventory.manage'});
      when(() => repo.listLevels(
            search: any(named: 'search'),
            forceRefresh: any(named: 'forceRefresh'),
            inStockOnly: any(named: 'inStockOnly'),
          )).thenAnswer((_) async => [
            _row('exp', name: 'Articaïne', qty: 20, expiresIn: -4),
            StockLevelData.fromJson(const {
              'id': 'q',
              'product_id': 'p-q',
              'product_name': 'Lot suspect',
              'location_id': 'loc-1',
              'location_name': 'Réserve centrale',
              'batch_id': 'b-q',
              'batch_number': 'Q1',
              'quantity': 5,
              'min_threshold': 1,
              'batch_status': 'quarantined',
            }),
          ]);
      await pumpStock(tester, const StockLevelListScreen());

      await tester.tap(find.text('Articaïne'));
      await tester.pumpAndSettle();
      expect(find.text('Sortie'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lot suspect'));
      await tester.pumpAndSettle();
      expect(find.text('Sortie'), findsNothing);
      expect(find.text('Transfert'), findsOneWidget);
    });

    testWidgets('the search bar\'s barcode button opens the product scanner',
        (tester) async {
      allow({'inventory.view'});
      await pumpStock(tester, const StockLevelListScreen());
      await tester.tap(find.byKey(const Key('stock-scan-product')));
      await tester.pumpAndSettle();
      expect(find.text('SCANNER mode=product'), findsOneWidget);
    });
  });

  group('lots', () {
    final lots = [
      BatchData.fromJson({
        'id': 'b-ok',
        'product_name': 'Gants nitrile',
        'supplier_name': 'Dental Plus',
        'batch_number': 'L-OK',
        'expiry_date': _day(200),
        'received_at': '2026-09-01T09:00:00+00:00',
        'status': 'active',
        'qty_on_hand': 45,
      }),
      BatchData.fromJson({
        'id': 'b-exp',
        'product_name': 'Articaïne',
        'supplier_name': 'MedStock',
        'batch_number': 'L-EXP',
        'expiry_date': _day(-3),
        'status': 'active',
        'qty_on_hand': 4,
      }),
      BatchData.fromJson({
        'id': 'b-q',
        'product_name': 'Compresses',
        'supplier_name': 'MedStock',
        'batch_number': 'L-Q',
        'expiry_date': _day(100),
        'status': 'quarantined',
        'qty_on_hand': 9,
      }),
    ];

    setUp(() {
      when(() => repo.listBatches()).thenAnswer((_) async => lots);
    });

    testWidgets('lists lots with supplier, status and counts per chip',
        (tester) async {
      allow({'inventory.view'});
      await pumpStock(tester, const BatchListScreen());

      expect(find.text('Tous (3)'), findsOneWidget);
      expect(find.text('Périmés (1)'), findsOneWidget);
      expect(find.text('Quarantaine (1)'), findsOneWidget);
      expect(find.text('DENTAL PLUS'), findsOneWidget);
      expect(find.text('Lot L-EXP'), findsOneWidget);
      // Expired first.
      expect(tester.getTopLeft(find.text('Lot L-EXP')).dy,
          lessThan(tester.getTopLeft(find.text('Lot L-OK')).dy));

      await tester.tap(find.text('Quarantaine (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Lot L-Q'), findsOneWidget);
      expect(find.text('Lot L-OK'), findsNothing);
    });

    testWidgets('a lot opens its traceability and where it is stored',
        (tester) async {
      allow({'inventory.view'});
      when(() => repo.listLevels(
            search: any(named: 'search'),
            forceRefresh: any(named: 'forceRefresh'),
            inStockOnly: any(named: 'inStockOnly'),
          )).thenAnswer((_) async => [
            StockLevelData.fromJson(const {
              'id': 's1',
              'product_id': 'p',
              'product_name': 'Gants nitrile',
              'product_unit': 'boîtes',
              'location_id': 'l1',
              'location_name': 'Salle 1',
              'batch_id': 'b-ok',
              'batch_number': 'L-OK',
              'quantity': 30,
            }),
            StockLevelData.fromJson(const {
              'id': 's2',
              'product_id': 'p',
              'product_name': 'Gants nitrile',
              'product_unit': 'boîtes',
              'location_id': 'l2',
              'location_name': 'Réserve',
              'batch_id': 'b-ok',
              'batch_number': 'L-OK',
              'quantity': 15,
            }),
          ]);
      await pumpStock(tester, const BatchListScreen());

      await tester.tap(find.text('Lot L-OK'));
      await tester.pumpAndSettle();
      expect(find.text('Traçabilité'.toUpperCase()), findsOneWidget);
      expect(find.text('Fournisseur'), findsOneWidget);
      expect(find.text('Dental Plus'), findsWidgets);
      expect(find.text('Où est ce lot ?'.toUpperCase()), findsOneWidget);
      expect(find.text('Salle 1'), findsOneWidget);
      expect(find.text('30 boîtes'), findsOneWidget);
      expect(find.text('Réserve'), findsOneWidget);
      // No movement for a role that cannot manage stock.
      expect(find.text('ACTIONS SUR CE LOT'), findsNothing);
    });

    testWidgets('lots with nothing left stay traceable but offer no movement',
        (tester) async {
      allow({'inventory.view', 'inventory.manage'});
      when(() => repo.listBatches()).thenAnswer((_) async => [
            BatchData.fromJson(const {
              'id': 'b-0',
              'product_name': 'Gants',
              'supplier_name': 'X',
              'batch_number': 'L-0',
              'status': 'active',
              'qty_on_hand': 0,
            }),
          ]);
      when(() => repo.listLevels(
            search: any(named: 'search'),
            forceRefresh: any(named: 'forceRefresh'),
            inStockOnly: any(named: 'inStockOnly'),
          )).thenAnswer((_) async => const <StockLevelData>[]);
      await pumpStock(tester, const BatchListScreen());
      expect(find.text('Épuisé'), findsOneWidget);
      await tester.tap(find.text('Lot L-0'));
      await tester.pumpAndSettle();
      expect(find.text('Ce lot n\'est présent dans aucun emplacement.'),
          findsOneWidget);
      expect(find.text('ACTIONS SUR CE LOT'), findsNothing);
    });
  });

  group('form helpers', () {
    testWidgets('quick amounts add to the quantity and never exceed the stock',
        (tester) async {
      final ctrl = TextEditingController(text: '3');
      addTearDown(ctrl.dispose);
      await pumpApp(
        tester,
        Scaffold(body: QuickAmountChips(controller: ctrl, max: 12)),
      );
      await tester.tap(find.byKey(const ValueKey('quick_add_5')));
      expect(ctrl.text, '8');
      await tester.tap(find.byKey(const ValueKey('quick_add_10')));
      expect(ctrl.text, '12', reason: 'capped at what is available');
    });

    testWidgets('a reason preset fills the reason, and shows as selected',
        (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      await pumpApp(
        tester,
        Scaffold(
          body: ReasonPresetChips(
            controller: ctrl,
            presets: const ['Casse ou avarie', 'Erreur de comptage'],
          ),
        ),
      );
      await tester.tap(find.text('Casse ou avarie'));
      await tester.pump();
      expect(ctrl.text, 'Casse ou avarie');
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Casse ou avarie'),
      );
      expect(chip.selected, isTrue);
    });
  });
}
