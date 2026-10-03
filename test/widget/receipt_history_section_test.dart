import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/cycles/data/models/cycle_attachment_data.dart';
import 'package:steriymed_mobile/features/purchases/data/models/goods_receipt_data.dart';
import 'package:steriymed_mobile/features/purchases/data/repositories/purchase_repository.dart';
import 'package:steriymed_mobile/features/purchases/presentation/widgets/receipt_history_section.dart';
import 'package:steriymed_mobile/shared/media/photo_source.dart';

import '../helpers/pump_app.dart';

class MockPurchaseRepository extends Mock implements PurchaseRepository {}

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

GoodsReceiptData _receipt(String id, {int proofs = 0, String? gap}) =>
    GoodsReceiptData(
      id: id,
      purchaseOrderId: 'po-1',
      totalLines: 1,
      receivedAt: DateTime(2026, 9, 20, 10, 30),
      receivedByName: 'Alice Dupont',
      locationId: 'loc-1',
      locationName: 'Réserve',
      attachmentsCount: proofs,
      lines: [
        GoodsReceiptLineData(
          id: 'rl-$id',
          productId: 'p1',
          productName: 'Gants nitrile M',
          batchId: 'b1',
          batchNumber: 'LOT-77',
          expiryDate: DateTime(2027, 5, 31),
          qty: 40,
          discrepancyReason: gap,
        ),
      ],
    );

void main() {
  late MockPurchaseRepository repo;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    repo = MockPurchaseRepository();
    if (GetIt.instance.isRegistered<PurchaseRepository>()) {
      GetIt.instance.unregister<PurchaseRepository>();
    }
    GetIt.instance.registerSingleton<PurchaseRepository>(repo);
  });

  tearDown(() => GetIt.instance.unregister<PurchaseRepository>());

  Future<void> pump(WidgetTester tester, {bool canAddProof = true}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: ReceiptHistorySection(
            poId: 'po-1',
            canAddProof: canAddProof,
            photoPicker: (_) async =>
                PickedPhoto('bl.png', Uint8List.fromList(_png)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows who received what, where, with lot and expiry', (tester) async {
    when(() => repo.receipts('po-1')).thenAnswer(
      (_) async => [_receipt('r1', proofs: 1, gap: 'Carton écrasé')],
    );

    await pump(tester);

    expect(find.text('20/09/2026 10:30'), findsOneWidget);
    expect(find.text('Par Alice Dupont · Réserve'), findsOneWidget);
    expect(find.textContaining('Lot LOT-77'), findsOneWidget);
    expect(find.textContaining('péremption 31/05/2027'), findsOneWidget);
    expect(find.textContaining('Écart : Carton écrasé'), findsOneWidget);
    expect(find.text('× 40'), findsOneWidget);
  });

  testWidgets('a receipt without a photo is flagged as missing proof', (tester) async {
    when(() => repo.receipts('po-1')).thenAnswer(
      (_) async => [_receipt('r1', proofs: 0), _receipt('r2', proofs: 2)],
    );

    await pump(tester);

    expect(find.text('JUSTIFICATIF MANQUANT'), findsOneWidget);
    expect(find.text('JUSTIFICATIF'), findsOneWidget);
    expect(find.text('Ajouter la photo'), findsOneWidget);
    expect(find.text('Ajouter une autre photo'), findsOneWidget);
    expect(find.text('Voir le justificatif'), findsOneWidget);
  });

  testWidgets('someone who cannot manage purchasing sees no add button', (tester) async {
    when(() => repo.receipts('po-1')).thenAnswer((_) async => [_receipt('r1')]);

    await pump(tester, canAddProof: false);

    expect(find.text('JUSTIFICATIF MANQUANT'), findsOneWidget);
    expect(find.text('Ajouter la photo'), findsNothing);
  });

  testWidgets('adding the missing photo uploads it and refreshes the list', (tester) async {
    var proofs = 0;
    when(() => repo.receipts('po-1')).thenAnswer((_) async => [_receipt('r1', proofs: proofs)]);
    when(() => repo.uploadReceiptProof(
          receiptId: any(named: 'receiptId'),
          fileName: any(named: 'fileName'),
          bytes: any(named: 'bytes'),
          onProgress: any(named: 'onProgress'),
        )).thenAnswer((_) async {
      proofs = 1;
      return const CycleAttachmentData(id: 'a1', url: 'u');
    });

    await pump(tester);
    await tester.tap(find.text('Ajouter la photo'));
    await tester.pumpAndSettle();

    verify(() => repo.uploadReceiptProof(
          receiptId: 'r1',
          fileName: 'bl.png',
          bytes: any(named: 'bytes'),
          onProgress: any(named: 'onProgress'),
        )).called(1);
    expect(find.text('JUSTIFICATIF MANQUANT'), findsNothing);
    expect(find.text('JUSTIFICATIF'), findsOneWidget);
  });

  testWidgets('a failed upload is reported and the receipt stays flagged', (tester) async {
    when(() => repo.receipts('po-1')).thenAnswer((_) async => [_receipt('r1')]);
    when(() => repo.uploadReceiptProof(
          receiptId: any(named: 'receiptId'),
          fileName: any(named: 'fileName'),
          bytes: any(named: 'bytes'),
          onProgress: any(named: 'onProgress'),
        )).thenThrow(const ApiException(code: 'ATTACHMENT_LIMIT_REACHED', message: 'x'));

    await pump(tester);
    await tester.tap(find.text('Ajouter la photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Le nombre maximal de justificatifs est atteint pour cette réception.'),
      findsOneWidget,
    );
    expect(find.text('JUSTIFICATIF MANQUANT'), findsOneWidget);
  });

  testWidgets('an empty history says so', (tester) async {
    when(() => repo.receipts('po-1')).thenAnswer((_) async => []);
    await pump(tester);
    expect(find.text('Aucune réception enregistrée.'), findsOneWidget);
  });

  testWidgets('a failed load is shown with a retry that works', (tester) async {
    var calls = 0;
    when(() => repo.receipts('po-1')).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw const ApiException(code: 'server_error', message: 'Erreur serveur');
      }
      return [_receipt('r1')];
    });
    await pump(tester);
    expect(find.textContaining('Historique des réceptions indisponible'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lot LOT-77'), findsOneWidget);
  });
}
