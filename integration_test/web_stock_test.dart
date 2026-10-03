// Journey S: stock work as the stock manager, in real Chrome against the dev
// backend, with server read-back after every write.
//   scan/lookup by barcode -> issue -> transfer -> adjust (reason required)
//   -> inventory count open / count / close -> read-back of every delta.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:steriymed_mobile/shared/widgets/inputs/quantity_stepper.dart';
import 'support/web_env.dart';

Future<void> pickSource(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('source_field')));
  await settle(tester, 1);
  await tester.tap(find.textContaining('Lot ${WebEnv.glovesLot}').last);
  await settle(tester, 1);
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await settle(tester, 0.3);
  await tester.tap(f);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('stock manager: lookup, issue, transfer, adjust, inventory', (
    tester,
  ) async {
    await launchApp(tester);
    await signIn(tester, 'stock_manager');

    expect(await ServerApi.stockOf(WebEnv.glovesLot, 'Reserve'), 20);

    // ---- stock list shows the product and its quick actions
    openScreen(tester, '/app/stock');
    expect(await waitFor(tester, find.text(WebEnv.glovesName)), isTrue);
    expect(find.text('Sortie'), findsOneWidget);
    expect(find.text('Ajustement'), findsOneWidget);
    expect(find.text('Transfert'), findsOneWidget);
    expect(find.text('Inventaires'), findsOneWidget);
    expectNoFrameError(tester, 'stock list');

    // ---- code lookup by barcode (what a product scan does)
    openScreen(tester, '/app/stock/code/${WebEnv.glovesBarcode}');
    expect(await waitFor(tester, find.textContaining('Lot ${WebEnv.glovesLot}')), isTrue);
    expect(find.text(WebEnv.glovesName), findsWidgets);
    expect(find.byTooltip('Sortie'), findsOneWidget);
    expectNoFrameError(tester, 'code lookup');

    openScreen(tester, '/app/stock/code/NOPE-0000');
    expect(await waitFor(tester, find.text('Aucun produit ni lot ne correspond à ce code.')), isTrue);

    // ---- issue 3
    openScreen(tester, '/app/stock/issue');
    expect(await waitFor(tester, find.byKey(const ValueKey('source_field'))), isTrue);
    await pickSource(tester);
    expect(find.text('Disponible : 20 boite'), findsOneWidget);
    await tester.enterText(_qtyField(), '3');
    await tapText(tester, 'Enregistrer la sortie');
    expect(await waitFor(tester, find.text('Sortie enregistrée.')), isTrue);
    await settle(tester, 1);
    expect(await ServerApi.stockOf(WebEnv.glovesLot, 'Reserve'), 17);

    // ---- more than available is refused before anything is sent
    openScreen(tester, '/app/stock/issue');
    expect(await waitFor(tester, find.byKey(const ValueKey('source_field'))), isTrue);
    await pickSource(tester);
    await tester.enterText(_qtyField(), '99');
    await tapText(tester, 'Enregistrer la sortie');
    await settle(tester, 1);
    expect(find.textContaining('Maximum 17'), findsOneWidget);
    expect(await ServerApi.stockOf(WebEnv.glovesLot, 'Reserve'), 17);

    // ---- transfer 2 Reserve -> Bloc
    openScreen(tester, '/app/stock/transfer');
    expect(await waitFor(tester, find.byKey(const ValueKey('source_field'))), isTrue);
    await pickSource(tester);
    await tester.tap(find.byKey(const ValueKey('destination')));
    await settle(tester, 1);
    await tester.tap(find.text('Bloc').last);
    await settle(tester, 1);
    await tester.enterText(_qtyField(), '2');
    await tapText(tester, 'Enregistrer le transfert');
    expect(await waitFor(tester, find.text('Transfert enregistré.')), isTrue);
    await settle(tester, 1);
    expect(await ServerApi.stockOf(WebEnv.glovesLot, 'Reserve'), 15);
    expect(await ServerApi.stockOf(WebEnv.glovesLot, 'Bloc'), 2);

    // ---- adjust: the reason is mandatory
    openScreen(tester, '/app/stock/adjust');
    expect(await waitFor(tester, find.byKey(const ValueKey('source_field'))), isTrue);
    await pickSource(tester);
    await tapText(tester, 'Enregistrer l\'ajustement');
    await settle(tester, 1);
    expect(find.text('Le motif est obligatoire pour un ajustement.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'Casse');
    await tapText(tester, 'Enregistrer l\'ajustement');
    expect(await waitFor(tester, find.text('Ajustement enregistré.')), isTrue);
    await settle(tester, 1);
    expect(await ServerApi.stockOf(WebEnv.glovesLot, 'Reserve'), 14);

    // ---- inventory count on Reserve: count 12 (system says 14) -> close
    openScreen(tester, '/app/inventory');
    expect(await waitFor(tester, find.text('Nouvel inventaire')), isTrue);
    await tester.tap(find.text('Nouvel inventaire'));
    await settle(tester, 1.5);
    await tester.tap(find.byKey(const ValueKey('inventory_location')));
    await settle(tester, 1);
    await tester.tap(find.text('Reserve').last);
    await settle(tester, 1);
    await tester.tap(find.text('Ouvrir l\'inventaire'));
    expect(await waitFor(tester, find.text('À compter (1)'), seconds: 15), isTrue);
    await tester.tap(find.text('Compter'));
    await settle(tester, 1);
    await tester.enterText(find.byKey(const ValueKey('count_qty')), '12');
    await tester.tap(find.text('Enregistrer'));
    expect(await waitFor(tester, find.text('-2')), isTrue);
    expect(await ServerApi.stockOf(WebEnv.glovesLot, 'Reserve'), 14,
        reason: 'counting alone must not touch stock');
    await tapText(tester, 'Terminer l\'inventaire');
    await settle(tester, 1);
    await tester.tap(find.text('Terminer').last);
    expect(await waitFor(tester, find.text('Inventaire terminé.')), isTrue);
    await settle(tester, 1);
    expect(await ServerApi.stockOf(WebEnv.glovesLot, 'Reserve'), 12);
    expectNoFrameError(tester, 'end of stock journey');

    await signOut(tester);

    // ---- the viewer sees stock but cannot move it
    await signIn(tester, 'viewer');
    openScreen(tester, '/app/stock');
    expect(await waitFor(tester, find.text(WebEnv.glovesName)), isTrue);
    expect(find.text('Sortie'), findsNothing);
    expect(find.text('Ajustement'), findsNothing);
    expect(find.text('Inventaires'), findsOneWidget);
    openScreen(tester, '/app/inventory');
    expect(await waitFor(tester, find.text('Inventaires')), isTrue);
    expect(find.text('Nouvel inventaire'), findsNothing);
    await signOut(tester);
    // ignore: avoid_print
    print('STOCK_JOURNEY_OK');
  });
}

/// The quantity box inside the stepper (the lot picker is also a text field).
Finder _qtyField() => find.descendant(
      of: find.byType(QuantityStepper),
      matching: find.byType(TextField),
    );
