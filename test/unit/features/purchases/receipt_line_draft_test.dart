import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/features/purchases/data/models/purchase_order_line_data.dart';
import 'package:steriymed_mobile/features/purchases/presentation/models/receipt_line_draft.dart';

PurchaseOrderLineData _line({int ordered = 10, int received = 0}) =>
    PurchaseOrderLineData(
      id: 'l1',
      productId: 'p1',
      productName: 'Gants',
      qtyOrdered: ordered,
      qtyReceived: received,
    );

void main() {
  final today = DateTime(2026, 10, 2);

  test('starts with the remaining quantity, and is "included" while above 0', () {
    final d = ReceiptLineDraft(_line(ordered: 10, received: 3));
    expect(d.qtyCtrl.text, '7');
    expect(d.included, isTrue);
    expect(d.differsFromOrder, isFalse);
    d.dispose();
  });

  test('a quantity different from what remains is flagged as a gap', () {
    final d = ReceiptLineDraft(_line());
    d.qtyCtrl.text = '4';
    expect(d.differsFromOrder, isTrue);
    d.dispose();
  });

  test('zero means "not arrived": the line is skipped and never asks for a lot', () {
    final d = ReceiptLineDraft(_line());
    d.qtyCtrl.text = '0';
    expect(d.included, isFalse);
    expect(d.qtyError, isNull);
    expect(d.lotError, isNull);
    expect(d.expiryError(today: today), isNull);
    expect(d.isValid(today: today), isTrue);
    d.dispose();
  });

  test('quantity must be a whole number between 0 and what remains', () {
    final d = ReceiptLineDraft(_line(ordered: 10, received: 4));
    for (final bad in ['', 'x', '-1', '1.5', '7']) {
      d.qtyCtrl.text = bad;
      expect(d.qtyError, isNotNull, reason: '"$bad" must be refused');
    }
    for (final ok in ['0', '1', '6']) {
      d.qtyCtrl.text = ok;
      expect(d.qtyError, isNull, reason: '"$ok" must be accepted');
    }
    d.dispose();
  });

  test('a lot number is required once something is received, and trimmed', () {
    final d = ReceiptLineDraft(_line());
    d.qtyCtrl.text = '5';
    expect(d.lotError, isNotNull);
    d.lotCtrl.text = '   ';
    expect(d.lotError, isNotNull);
    d.lotCtrl.text = '  LOT-9 ';
    expect(d.lotError, isNull);
    expect(d.toPayload()['batch_number'], 'LOT-9');
    d.dispose();
  });

  test('an expiry date is required unless the user says there is none', () {
    final d = ReceiptLineDraft(_line());
    d.qtyCtrl.text = '5';
    expect(d.expiryError(today: today), isNotNull);

    d.noExpiry = true;
    expect(d.expiryError(today: today), isNull);
    expect(d.toPayload().containsKey('expiry_date'), isFalse);
    d.dispose();
  });

  test('today is accepted, yesterday is refused', () {
    final d = ReceiptLineDraft(_line());
    d.qtyCtrl.text = '5';
    d.expiry = DateTime(2026, 10, 2, 18);
    expect(d.expiryError(today: DateTime(2026, 10, 2, 8)), isNull);
    d.expiry = DateTime(2026, 10, 1);
    expect(d.expiryError(today: today), isNotNull);
    d.dispose();
  });

  test('the payload carries the date as yyyy-MM-dd and the gap reason only when typed', () {
    final d = ReceiptLineDraft(_line());
    d.qtyCtrl.text = '6';
    d.lotCtrl.text = 'LOT-1';
    d.expiry = DateTime(2027, 3, 9);
    expect(d.toPayload(), {
      'purchase_order_line_id': 'l1',
      'batch_number': 'LOT-1',
      'qty': 6,
      'expiry_date': '2027-03-09',
    });
    d.reasonCtrl.text = ' carton écrasé ';
    expect(d.toPayload()['discrepancy_reason'], 'carton écrasé');
    d.dispose();
  });

  test('a line with nothing left cannot be received', () {
    final d = ReceiptLineDraft(_line(ordered: 5, received: 5));
    expect(d.isComplete, isTrue);
    expect(d.included, isFalse);
    expect(d.qtyError, isNull);
    d.dispose();
  });
}
