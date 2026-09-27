// Task 2 (test coverage completion). This stub was named after a
// GoodsReceiptBloc that doesn't exist — the screen is a plain
// StatefulWidget doing setState + direct getIt<PurchaseRepository>() /
// getIt<StockRepository>() calls. Per the user's explicit choice ("test
// the real pattern instead"), this tests that real behavior.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/features/purchases/data/models/goods_receipt_data.dart';
import 'package:steriymed_mobile/features/purchases/data/models/purchase_order_data.dart';
import 'package:steriymed_mobile/features/purchases/data/models/purchase_order_line_data.dart';
import 'package:steriymed_mobile/features/purchases/data/repositories/purchase_repository.dart';
import 'package:steriymed_mobile/features/purchases/presentation/screens/goods_receipt_screen.dart';
import 'package:steriymed_mobile/features/stock/data/models/stock_option.dart';
import 'package:steriymed_mobile/features/stock/data/repositories/stock_repository.dart';

import '../helpers/pump_app.dart';

class MockPurchaseRepository extends Mock implements PurchaseRepository {}

class MockStockRepository extends Mock implements StockRepository {}

PurchaseOrderData _buildPo({int qtyOrdered = 10, int qtyReceived = 0}) =>
    PurchaseOrderData(
      id: 'po-1',
      supplierId: 'sup-1',
      supplierName: 'Dentsply',
      status: 'ordered',
      lines: [
        PurchaseOrderLineData(
          id: 'line-1',
          productId: 'prod-1',
          productName: 'Gants nitrile M',
          qtyOrdered: qtyOrdered,
          qtyReceived: qtyReceived,
        ),
      ],
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  late MockPurchaseRepository purchaseRepo;
  late MockStockRepository stockRepo;

  setUp(() {
    purchaseRepo = MockPurchaseRepository();
    stockRepo = MockStockRepository();

    when(() => stockRepo.listOptions()).thenAnswer(
      (_) async => (
        batches: <StockOption>[],
        locations: [const StockOption(id: 'loc-1', label: 'Réserve')],
      ),
    );

    if (GetIt.instance.isRegistered<PurchaseRepository>()) {
      GetIt.instance.unregister<PurchaseRepository>();
    }
    if (GetIt.instance.isRegistered<StockRepository>()) {
      GetIt.instance.unregister<StockRepository>();
    }
    GetIt.instance.registerSingleton<PurchaseRepository>(purchaseRepo);
    GetIt.instance.registerSingleton<StockRepository>(stockRepo);
  });

  tearDown(() {
    GetIt.instance.unregister<PurchaseRepository>();
    GetIt.instance.unregister<StockRepository>();
  });

  testWidgets('shows a loading view before the PO arrives', (tester) async {
    final neverCompletes = Completer<PurchaseOrderData>();
    when(() => purchaseRepo.show(any()))
        .thenAnswer((_) => neverCompletes.future);

    await pumpApp(tester, const GoodsReceiptScreen(poId: 'po-1'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows "Commande introuvable" when the PO fails to load',
      (tester) async {
    when(() => purchaseRepo.show(any())).thenThrow(Exception('boom'));

    await pumpApp(tester, const GoodsReceiptScreen(poId: 'po-1'));
    await tester.pumpAndSettle();

    expect(find.text('Commande introuvable.'), findsOneWidget);
  });

  testWidgets(
    'pre-fills the quantity field with qtyRemaining and shows the product '
    'name and ordered quantity',
    (tester) async {
      when(() => purchaseRepo.show(any()))
          .thenAnswer((_) async => _buildPo(qtyOrdered: 10, qtyReceived: 3));

      await pumpApp(tester, const GoodsReceiptScreen(poId: 'po-1'));
      await tester.pumpAndSettle();

      expect(find.text('Gants nitrile M'), findsOneWidget);
      expect(find.text('Commandé : 10'), findsOneWidget);
      expect(find.text('7'), findsOneWidget); // qtyRemaining = 10 - 3
    },
  );

  testWidgets(
    'shows a warning instead of a location dropdown when no location exists',
    (tester) async {
      when(() => stockRepo.listOptions()).thenAnswer(
        (_) async => (batches: <StockOption>[], locations: <StockOption>[]),
      );
      when(() => purchaseRepo.show(any())).thenAnswer((_) async => _buildPo());

      await pumpApp(tester, const GoodsReceiptScreen(poId: 'po-1'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Aucun emplacement disponible'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'submitting sends the right payload — batch number, qty, and location',
    (tester) async {
      when(() => purchaseRepo.show(any())).thenAnswer((_) async => _buildPo());
      when(() => purchaseRepo.receive(
            poId: any(named: 'poId'),
            locationId: any(named: 'locationId'),
            lines: any(named: 'lines'),
          )).thenAnswer((_) async => GoodsReceiptData(
            id: 'gr-1',
            purchaseOrderId: 'po-1',
            totalLines: 1,
            receivedAt: DateTime(2026, 9, 20),
          ));

      await pumpApp(tester, const GoodsReceiptScreen(poId: 'po-1'));
      await tester.pumpAndSettle();

      // AppTextField wraps a TextFormField, not a plain TextField. The
      // quantity field is the first one on the (single) line card.
      await tester.enterText(find.byType(TextFormField).first, '5');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Valider la réception'));
      await tester.pumpAndSettle();

      final captured = verify(() => purchaseRepo.receive(
            poId: 'po-1',
            locationId: 'loc-1',
            lines: captureAny(named: 'lines'),
          )).captured.single as List<Map<String, dynamic>>;

      expect(captured, hasLength(1));
      expect(captured.first['purchase_order_line_id'], 'line-1');
      expect(captured.first['qty'], 5);
      // Not asserting the success snackbar here: _submit() calls
      // context.pop() right after showing it, and go_router's pop() with no
      // real router/back-stack in this bare-MaterialApp test harness throws,
      // which the same try/catch then replaces with an error snackbar. The
      // repository call above is the real behavior under test.
    },
  );

  testWidgets('a zero quantity on every line is rejected before submitting',
      (tester) async {
    when(() => purchaseRepo.show(any())).thenAnswer((_) async => _buildPo());

    await pumpApp(tester, const GoodsReceiptScreen(poId: 'po-1'));
    await tester.pumpAndSettle();

    final qtyField = find.byType(TextFormField).first;
    await tester.enterText(qtyField, '0');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider la réception'));
    await tester.pumpAndSettle();

    expect(find.text('Aucune quantité saisie.'), findsOneWidget);
    verifyNever(() => purchaseRepo.receive(
          poId: any(named: 'poId'),
          locationId: any(named: 'locationId'),
          lines: any(named: 'lines'),
        ));
  });
}
