// Journey: receive an ordered purchase order (Cahier §5 journey 2, "receive a
// lot with expiry"). The seed leaves one PO ordered and not received.
//   stock manager opens the receipt, picks the place, types quantity, lot and
//   expiry, confirms -> the server holds exactly that lot, quantity and place.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../support/journey_helpers.dart';
import '../support/live_backend_guard.dart';
import '../support/web_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'stock manager receives a PO with lot and expiry; the server holds them',
    (tester) async {
      final po = (await ServerApi.get('/v1/purchase-orders/${WebEnv.poId}')) as Map;
      final order = (po['data'] ?? po) as Map;
      final line = (order['lines'] as List).cast<Map>().first;
      final lineId = line['id'] as String;
      final lot = 'LOT-J${DateTime.now().millisecondsSinceEpoch % 100000}';
      final expiry = DateTime.now().add(const Duration(days: 300));

      await launchApp(tester);
      await signIn(tester, 'stock_manager');

      openScreen(tester, '/app/purchases/${WebEnv.poId}/receive');
      expect(await waitFor(tester, find.text('Réception marchandise')), isTrue);
      await settle(tester, 1);

      // place
      await tester.tap(find.text('Emplacement de réception *'));
      await settle(tester, 1);
      await tester.tap(find.text('Reserve').last);
      await settle(tester, 1);

      // quantity, lot, expiry
      await tester.enterText(find.byKey(ValueKey('qty_$lineId')), '10');
      await tester.enterText(find.byKey(ValueKey('lot_$lineId')), lot);
      await pickDate(tester, find.byKey(ValueKey('exp_$lineId')), expiry);

      await tapVisible(tester, find.text('Valider la réception'));
      expect(await waitFor(tester, find.text('Valider la réception ?')), isTrue);
      await tester.tap(find.text('Valider'));
      expect(
        await waitFor(tester, find.textContaining('Réception enregistrée'), seconds: 20),
        isTrue,
        reason: 'the receipt must be confirmed on screen',
      );
      await settle(tester, 1);

      // server read-back: that lot, that quantity, that place
      expect(await ServerApi.stockOf(lot, 'Reserve'), 10);
      final batch = await firstWhere(
        '/v1/batches?limit=200',
        (b) => b['batch_number'] == lot,
      );
      expect((batch['expiry_date'] as String).startsWith(
          '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}'),
          isTrue);
      expectNoFrameError(tester, 'goods receipt journey');
      await signOut(tester);
    },
    skip: kSkipUnlessLiveBackend,
  );
}
