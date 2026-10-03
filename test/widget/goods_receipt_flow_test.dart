// The goods receipt screen is a plain StatefulWidget (no bloc): it talks to
// PurchaseRepository / StockRepository directly, so that is what is tested.
//
// Phase 5 contract under test: the lot number and expiry date are the ones
// typed from the packaging (never invented), the quantity can never exceed
// what is still expected, a delivery is confirmed before it is sent, the
// receipt is recorded before the photo, and a photo that fails to send leaves
// a visible, retryable state instead of a lost receipt.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/router/routes.dart';
import 'package:steriymed_mobile/features/cycles/data/models/cycle_attachment_data.dart';
import 'package:steriymed_mobile/features/purchases/data/models/goods_receipt_data.dart';
import 'package:steriymed_mobile/features/purchases/data/models/purchase_order_data.dart';
import 'package:steriymed_mobile/features/purchases/data/models/purchase_order_line_data.dart';
import 'package:steriymed_mobile/features/purchases/data/repositories/purchase_repository.dart';
import 'package:steriymed_mobile/features/purchases/presentation/screens/goods_receipt_screen.dart';
import 'package:steriymed_mobile/features/stock/data/models/stock_option.dart';
import 'package:steriymed_mobile/features/stock/data/repositories/stock_repository.dart';
import 'package:steriymed_mobile/shared/media/photo_source.dart';
import 'package:steriymed_mobile/shared/widgets/buttons/primary_button.dart';

import '../helpers/pump_app.dart';

class MockPurchaseRepository extends Mock implements PurchaseRepository {}

class MockStockRepository extends Mock implements StockRepository {}

// A real 1x1 PNG so Image.memory has something valid to decode.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

PurchaseOrderData _buildPo({int qtyOrdered = 10, int qtyReceived = 0}) =>
    PurchaseOrderData(
      id: 'po-1',
      supplierId: 'sup-1',
      supplierName: 'Dentsply',
      status: qtyReceived == 0 ? 'ordered' : 'partially_received',
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

GoodsReceiptData _receipt({bool queued = false}) => GoodsReceiptData(
  id: queued ? 'queued-1' : 'gr-1',
  purchaseOrderId: 'po-1',
  totalLines: 1,
  receivedAt: DateTime(2026, 9, 20),
  isQueued: queued,
);

Finder _field(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextFormField),
);

void main() {
  late MockPurchaseRepository purchaseRepo;
  late MockStockRepository stockRepo;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    purchaseRepo = MockPurchaseRepository();
    stockRepo = MockStockRepository();

    when(() => stockRepo.listOptions(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer(
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

  /// Tall enough that nothing needs scrolling, and a router with a parent route
  /// so the screen's pop (after a success) has somewhere to go.
  Future<void> pumpScreen(WidgetTester tester, {PhotoPicker? picker}) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/home/receive',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('HOME')),
          routes: [
            GoRoute(
              path: 'receive',
              builder: (_, __) =>
                  GoodsReceiptScreen(poId: 'po-1', photoPicker: picker),
            ),
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

  Future<void> fillValidLine(WidgetTester tester, {String qty = '5'}) async {
    await tester.enterText(_field('qty_line-1'), qty);
    await tester.pump();
    await tester.enterText(_field('lot_line-1'), 'LOT-ABC-42');
    await tester.tap(find.byKey(const ValueKey('noexp_line-1')));
    await tester.pump();
  }

  Future<void> submitAndConfirm(WidgetTester tester) async {
    await tester.tap(find.text('Valider la réception'));
    await tester.pumpAndSettle();
  }

  void stubReceive(GoodsReceiptData result) {
    when(() => purchaseRepo.receive(
          poId: any(named: 'poId'),
          locationId: any(named: 'locationId'),
          lines: any(named: 'lines'),
        )).thenAnswer((_) async => result);
  }

  group('loading', () {
    testWidgets('shows a loading view before the PO arrives', (tester) async {
      final neverCompletes = Completer<PurchaseOrderData>();
      when(() => purchaseRepo.show(any()))
          .thenAnswer((_) => neverCompletes.future);

      await pumpApp(tester, const GoodsReceiptScreen(poId: 'po-1'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('a failed load says so and offers a retry that works',
        (tester) async {
      var calls = 0;
      when(() => purchaseRepo.show(any())).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw Exception('boom');
        return _buildPo();
      });

      await pumpScreen(tester);
      expect(find.text('Réessayer'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Gants nitrile M'), findsOneWidget);
    });

    testWidgets('shows what is ordered, already received and still to come',
        (tester) async {
      when(() => purchaseRepo.show(any()))
          .thenAnswer((_) async => _buildPo(qtyOrdered: 10, qtyReceived: 3));

      await pumpScreen(tester);

      expect(find.text('Gants nitrile M'), findsOneWidget);
      expect(
        find.text('Commandé : 10 · déjà reçu : 3 · reste : 7'),
        findsOneWidget,
      );
      // Pre-filled with what remains.
      final qty = tester.widget<TextFormField>(_field('qty_line-1'));
      expect(qty.controller!.text, '7');
    });

    testWidgets('warns when the practice has no storage location',
        (tester) async {
      when(() => stockRepo.listOptions(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer(
        (_) async => (batches: <StockOption>[], locations: <StockOption>[]),
      );
      when(() => purchaseRepo.show(any())).thenAnswer((_) async => _buildPo());

      await pumpScreen(tester);

      expect(find.textContaining('Aucun emplacement de stock'), findsOneWidget);
    });

    testWidgets('a line that is already complete cannot be received again',
        (tester) async {
      when(() => purchaseRepo.show(any()))
          .thenAnswer((_) async => _buildPo(qtyOrdered: 4, qtyReceived: 4));

      await pumpScreen(tester);

      expect(find.textContaining('complet (4/4)'), findsOneWidget);
      expect(find.byKey(const ValueKey('qty_line-1')), findsNothing);
    });
  });

  group('validation (nothing is sent until the form is right)', () {
    setUp(() {
      when(() => purchaseRepo.show(any())).thenAnswer((_) async => _buildPo());
    });

    void expectNothingSent() => verifyNever(() => purchaseRepo.receive(
          poId: any(named: 'poId'),
          locationId: any(named: 'locationId'),
          lines: any(named: 'lines'),
        ));

    testWidgets('a zero quantity on every line is refused', (tester) async {
      await pumpScreen(tester);
      await tester.enterText(_field('qty_line-1'), '0');
      await submitAndConfirm(tester);

      expect(find.text('Aucune quantité à réceptionner.'), findsOneWidget);
      expectNothingSent();
    });

    testWidgets('a lot number is required: none is invented', (tester) async {
      await pumpScreen(tester);
      await tester.enterText(_field('qty_line-1'), '5');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('noexp_line-1')));
      await tester.pump();
      await submitAndConfirm(tester);

      expect(
        find.text('Numéro de lot requis (inscrit sur l\'emballage).'),
        findsOneWidget,
      );
      expectNothingSent();
    });

    testWidgets('the expiry date is required unless the product has none',
        (tester) async {
      await pumpScreen(tester);
      await tester.enterText(_field('qty_line-1'), '5');
      await tester.enterText(_field('lot_line-1'), 'LOT-1');
      await tester.pump();
      await submitAndConfirm(tester);

      expect(
        find.text('Date de péremption requise (ou cochez « sans date »).'),
        findsOneWidget,
      );
      expectNothingSent();
    });

    testWidgets('more than what remains is refused with the maximum shown',
        (tester) async {
      await pumpScreen(tester);
      await tester.enterText(_field('qty_line-1'), '11');
      await tester.pump();

      expect(
        find.text('Maximum 10 : c\'est ce qui reste à recevoir.'),
        findsOneWidget,
      );
      await tester.enterText(_field('lot_line-1'), 'LOT-1');
      await submitAndConfirm(tester);
      expectNothingSent();
    });

    testWidgets('a negative or non-numeric quantity is refused', (tester) async {
      await pumpScreen(tester);
      await tester.enterText(_field('qty_line-1'), 'abc');
      await tester.pump();
      expect(find.text('Entrez un nombre entier positif.'), findsOneWidget);
      await tester.enterText(_field('qty_line-1'), '-3');
      await tester.pump();
      expect(find.text('Entrez un nombre entier positif.'), findsOneWidget);
    });

    testWidgets('declining the confirmation sends nothing', (tester) async {
      await pumpScreen(tester);
      await fillValidLine(tester);
      await tester.tap(find.text('Valider la réception'));
      await tester.pumpAndSettle();
      expect(find.text('Valider la réception ?'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expectNothingSent();
    });
  });

  group('sending', () {
    setUp(() {
      when(() => purchaseRepo.show(any())).thenAnswer((_) async => _buildPo());
    });

    testWidgets('sends the lot, the quantity and the place the user typed',
        (tester) async {
      stubReceive(_receipt());
      await pumpScreen(tester);
      await fillValidLine(tester);

      await tester.tap(find.text('Valider la réception'));
      await tester.pumpAndSettle();
      // The summary says what is about to enter the stock.
      expect(find.textContaining('5 unité(s) sur 1 ligne(s)'), findsOneWidget);
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      final captured = verify(() => purchaseRepo.receive(
            poId: 'po-1',
            locationId: 'loc-1',
            lines: captureAny(named: 'lines'),
          )).captured.single as List<Map<String, dynamic>>;
      expect(captured, hasLength(1));
      expect(captured.first['purchase_order_line_id'], 'line-1');
      expect(captured.first['batch_number'], 'LOT-ABC-42');
      expect(captured.first['qty'], 5);
      expect(captured.first.containsKey('expiry_date'), isFalse);
    });

    testWidgets('a picked expiry date is sent as yyyy-MM-dd', (tester) async {
      stubReceive(_receipt());
      await pumpScreen(tester);
      await tester.enterText(_field('lot_line-1'), 'LOT-DATE');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('exp_line-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Valider la réception'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      final captured = verify(() => purchaseRepo.receive(
            poId: 'po-1',
            locationId: 'loc-1',
            lines: captureAny(named: 'lines'),
          )).captured.single as List<Map<String, dynamic>>;
      expect(
        captured.first['expiry_date'],
        DateFormat('yyyy-MM-dd').format(DateTime.now()),
      );
      expect(captured.first['qty'], 10);
    });

    testWidgets('a partial delivery explains the gap and sends the reason',
        (tester) async {
      stubReceive(_receipt());
      await pumpScreen(tester);
      await fillValidLine(tester, qty: '6');
      await tester.enterText(_field('why_line-1'), 'Carton écrasé');
      await tester.pump();

      await tester.tap(find.text('Valider la réception'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      final captured = verify(() => purchaseRepo.receive(
            poId: 'po-1',
            locationId: 'loc-1',
            lines: captureAny(named: 'lines'),
          )).captured.single as List<Map<String, dynamic>>;
      expect(captured.first['discrepancy_reason'], 'Carton écrasé');
    });

    testWidgets('tapping twice sends one receipt', (tester) async {
      final gate = Completer<GoodsReceiptData>();
      when(() => purchaseRepo.receive(
            poId: any(named: 'poId'),
            locationId: any(named: 'locationId'),
            lines: any(named: 'lines'),
          )).thenAnswer((_) => gate.future);
      await pumpScreen(tester);
      await fillValidLine(tester);

      await tester.tap(find.text('Valider la réception'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pump();
      // The button is busy now: a second tap must not start a second send.
      await tester.tap(find.byType(PrimaryButton).last, warnIfMissed: false);
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton).last, warnIfMissed: false);
      await tester.pump();

      verify(() => purchaseRepo.receive(
            poId: any(named: 'poId'),
            locationId: any(named: 'locationId'),
            lines: any(named: 'lines'),
          )).called(1);
      gate.complete(_receipt());
      await tester.pumpAndSettle();
    });

    testWidgets('a rejection from the server is shown and the form is kept',
        (tester) async {
      when(() => purchaseRepo.receive(
            poId: any(named: 'poId'),
            locationId: any(named: 'locationId'),
            lines: any(named: 'lines'),
          )).thenThrow(const ApiException(
        code: 'RECEIPT_EXCEEDS_ORDERED',
        message: 'Il ne reste que 3 unité(s).',
      ));
      await pumpScreen(tester);
      await fillValidLine(tester);
      await tester.tap(find.text('Valider la réception'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'La quantité reçue dépasse ce qui reste à réceptionner sur la ligne.',
        ),
        findsOneWidget,
      );
      // Still on the form with the typed values.
      expect(find.text('Valider la réception'), findsOneWidget);
      final lot = tester.widget<TextFormField>(_field('lot_line-1'));
      expect(lot.controller!.text, 'LOT-ABC-42');
    });

    testWidgets(
      'a queued (offline) receive shows "Enregistré localement" with a '
      '"Voir la file" action',
      (tester) async {
        stubReceive(_receipt(queued: true));
        await pumpScreen(tester);
        await fillValidLine(tester);
        await tester.tap(find.text('Valider la réception'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Valider'));
        await tester.pump();
        await tester.pump();

        expect(
          find.text('Enregistré localement. Synchronisation en attente.'),
          findsOneWidget,
        );
        expect(find.text('Voir la file'), findsOneWidget);
      },
    );
  });

  group('proof photo', () {
    PhotoPicker picker() =>
        (_) async => PickedPhoto('bon-livraison.png', Uint8List.fromList(_png));

    setUp(() {
      when(() => purchaseRepo.show(any())).thenAnswer((_) async => _buildPo());
      stubReceive(_receipt());
    });

    Future<void> receiveWithPhoto(WidgetTester tester) async {
      await pumpScreen(tester, picker: picker());
      await fillValidLine(tester);
      await tester.tap(find.byKey(const ValueKey('add_proof')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider la réception'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
    }

    testWidgets('the photo is sent to the receipt that was just recorded',
        (tester) async {
      when(() => purchaseRepo.uploadReceiptProof(
            receiptId: any(named: 'receiptId'),
            fileName: any(named: 'fileName'),
            bytes: any(named: 'bytes'),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async => const CycleAttachmentData(id: 'a1', url: 'u'));

      await receiveWithPhoto(tester);

      verify(() => purchaseRepo.uploadReceiptProof(
            receiptId: 'gr-1',
            fileName: 'bon-livraison.png',
            bytes: any(named: 'bytes'),
            onProgress: any(named: 'onProgress'),
          )).called(1);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets(
      'when the photo fails the receipt stays recorded, the failure is shown '
      'and a retry sends the same photo',
      (tester) async {
        var attempts = 0;
        var receipts = 0;
        when(() => purchaseRepo.receive(
              poId: any(named: 'poId'),
              locationId: any(named: 'locationId'),
              lines: any(named: 'lines'),
            )).thenAnswer((_) async {
          receipts++;
          return _receipt();
        });
        when(() => purchaseRepo.uploadReceiptProof(
              receiptId: any(named: 'receiptId'),
              fileName: any(named: 'fileName'),
              bytes: any(named: 'bytes'),
              onProgress: any(named: 'onProgress'),
            )).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) {
            throw const ApiException(code: 'network_error', message: 'Hors ligne');
          }
          return const CycleAttachmentData(id: 'a1', url: 'u');
        });

        await receiveWithPhoto(tester);

        // The receipt went through exactly once; the photo is the open item.
        expect(receipts, 1);
        expect(find.text('Réception enregistrée'), findsOneWidget);
        expect(find.textContaining('n\'a pas pu être envoyée'), findsOneWidget);
        expect(find.textContaining('justificatif manquant'), findsOneWidget);

        await tester.tap(find.text('Réessayer l\'envoi'));
        await tester.pumpAndSettle();

        expect(attempts, 2);
        // Retrying the photo never records the receipt a second time.
        expect(receipts, 1);
        expect(find.text('HOME'), findsOneWidget);
      },
    );

    testWidgets('the user can finish without the photo', (tester) async {
      when(() => purchaseRepo.uploadReceiptProof(
            receiptId: any(named: 'receiptId'),
            fileName: any(named: 'fileName'),
            bytes: any(named: 'bytes'),
            onProgress: any(named: 'onProgress'),
          )).thenThrow(const ApiException(code: 'server_error', message: 'x'));

      await receiveWithPhoto(tester);
      await tester.tap(find.text('Terminer sans justificatif'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('without a photo the receipt is recorded and the user is told '
        'to add one later', (tester) async {
      await pumpScreen(tester);
      await fillValidLine(tester);
      await tester.tap(find.text('Valider la réception'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pump();
      await tester.pump();

      verifyNever(() => purchaseRepo.uploadReceiptProof(
            receiptId: any(named: 'receiptId'),
            fileName: any(named: 'fileName'),
            bytes: any(named: 'bytes'),
            onProgress: any(named: 'onProgress'),
          ));
      expect(find.textContaining('Pensez à ajouter la photo'), findsOneWidget);
    });

    testWidgets('a chosen photo can be removed before sending', (tester) async {
      await pumpScreen(tester, picker: picker());
      await tester.tap(find.byKey(const ValueKey('add_proof')));
      await tester.pumpAndSettle();
      expect(find.text('bon-livraison.png'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('remove_proof')));
      await tester.pumpAndSettle();
      expect(find.text('bon-livraison.png'), findsNothing);
      expect(find.byKey(const ValueKey('add_proof')), findsOneWidget);
    });
  });
}
