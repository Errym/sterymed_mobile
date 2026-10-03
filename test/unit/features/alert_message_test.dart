// The server writes alert texts in English; the clinic reads French.

import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/features/alerts/data/models/alert_message.dart';

void main() {
  test('low stock', () {
    expect(
      localizeAlertMessage('low_stock', 'Stock for "Gants nitrile M" is below threshold (2/10).'),
      'Stock de « Gants nitrile M » sous le seuil (2 sur 10).',
    );
  });

  test('expired and near-expiry batches, with a French date', () {
    expect(
      localizeAlertMessage('expired', 'Batch "LOT-0410" expired on 2026-09-30.'),
      'Lot « LOT-0410 » périmé depuis le 30/09/2026.',
    );
    expect(
      localizeAlertMessage('near_expiry', 'Batch "LOT-0510" expires on 2026-10-25.'),
      'Lot « LOT-0510 » expire le 25/10/2026.',
    );
  });

  test('a failed control test names the test in French', () {
    expect(
      localizeAlertMessage('failed_cycle', 'Cycle #12 failed a bowie_dick control test.'),
      'Cycle n°12 : test de Bowie-Dick échoué.',
    );
    expect(
      localizeAlertMessage('failed_cycle', 'Cycle #7 failed a vacuum control test.'),
      'Cycle n°7 : test de vide échoué.',
    );
  });

  test('a product name containing quotes is kept whole', () {
    expect(
      localizeAlertMessage('low_stock', 'Stock for "Fraise 1/2" ronde" is below threshold (0/5).'),
      'Stock de « Fraise 1/2" ronde » sous le seuil (0 sur 5).',
    );
  });

  test('anything unrecognised is shown exactly as received', () {
    expect(localizeAlertMessage('low_stock', 'Something new the server says'), 'Something new the server says');
    expect(localizeAlertMessage('mystery', 'Batch "X" expired on 2026-01-01.'), 'Batch "X" expired on 2026-01-01.');
    expect(localizeAlertMessage('expired', ''), '');
  });
}
