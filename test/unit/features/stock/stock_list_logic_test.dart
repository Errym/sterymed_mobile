// The rules behind the Stock option's lists: what is most critical comes
// first, the headline figures are computed from real rows (never invented),
// and a lot's expiry is judged in whole calendar days.

import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/features/stock/data/models/batch_data.dart';
import 'package:steriymed_mobile/features/stock/data/models/stock_level_data.dart';
import 'package:steriymed_mobile/features/stock/presentation/bloc/stock_level_list_bloc.dart';

String _day(int offset) {
  final d = DateTime.now().add(Duration(days: offset));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

StockLevelData _row(
  String id, {
  required int qty,
  int min = 10,
  int? expiresInDays,
  String name = 'Produit',
  String product = 'p',
}) =>
    StockLevelData.fromJson({
      'id': id,
      'product_id': '$product$id',
      'product_name': name,
      'quantity': qty,
      'min_threshold': min,
      if (expiresInDays != null) 'expiry_date': _day(expiresInDays),
    });

StockLevelListState _state(List<StockLevelData> rows,
        {StockFilter filter = StockFilter.all, String query = ''}) =>
    StockLevelListState(
      status: StockLevelStatus.success,
      levels: rows,
      filter: filter,
      query: query,
    );

void main() {
  group('criticity order', () {
    test('expired, then under the minimum, then near expiry, then fine', () {
      final ok = _row('ok', qty: 50, name: 'A fine');
      final near = _row('near', qty: 50, expiresInDays: 10, name: 'B near');
      final low = _row('low', qty: 3, name: 'C low');
      final expired = _row('exp', qty: 50, expiresInDays: -2, name: 'D expired');
      final order = _state([ok, near, low, expired]).filtered.map((r) => r.id);
      expect(order, ['exp', 'low', 'near', 'ok']);
    });

    test('rows of equal urgency keep a stable A-Z order', () {
      final b = _row('b', qty: 50, name: 'Bandes');
      final a = _row('a', qty: 50, name: 'Aiguilles');
      expect(_state([b, a]).filtered.map((r) => r.id), ['a', 'b']);
    });
  });

  group('headline figures', () {
    test('health is the share of rows neither low nor expired', () {
      final s = _state([
        _row('1', qty: 50),
        _row('2', qty: 50),
        _row('3', qty: 3), // low
        _row('4', qty: 50, expiresInDays: -1), // expired
      ]);
      expect(s.healthPercent, 50);
    });

    test('a row that is both low and expired counts once against health', () {
      final s = _state([
        _row('1', qty: 3, expiresInDays: -1),
        _row('2', qty: 50),
      ]);
      expect(s.healthPercent, 50);
    });

    test('no rows means "nothing to judge", not 100%', () {
      expect(_state(const <StockLevelData>[]).healthPercent, isNull);
    });

    test('urgent reorder counts distinct products, not rows', () {
      final s = _state([
        // The same product, short in two places.
        StockLevelData.fromJson(const {
          'id': 'a',
          'product_id': 'same',
          'product_name': 'Gants',
          'quantity': 1,
          'min_threshold': 10,
        }),
        StockLevelData.fromJson(const {
          'id': 'b',
          'product_id': 'same',
          'product_name': 'Gants',
          'quantity': 2,
          'min_threshold': 10,
        }),
        _row('c', qty: 50),
      ]);
      expect(s.urgentReorderCount, 1);
    });
  });

  group('filters and search', () {
    final rows = [
      _row('low', qty: 3, name: 'Compresses'),
      _row('exp', qty: 50, expiresInDays: -5, name: 'Sérum'),
      _row('per', qty: 50, expiresInDays: 90, name: 'Articaïne'),
      _row('ok', qty: 50, name: 'Gants'),
    ];

    test('each chip narrows to its own family', () {
      expect(_state(rows, filter: StockFilter.low).filtered.map((r) => r.id),
          ['low']);
      expect(
          _state(rows, filter: StockFilter.expired).filtered.map((r) => r.id),
          ['exp']);
      // Perishable = has a date and is not already expired.
      expect(
          _state(rows, filter: StockFilter.perishable)
              .filtered
              .map((r) => r.id),
          ['per']);
    });

    test('the chip counts match what the chip shows', () {
      final s = _state(rows);
      for (final f in StockFilter.values) {
        expect(s.countFor(f), _state(rows, filter: f).filtered.length,
            reason: '$f');
      }
    });

    test('search composes with the chip', () {
      final s = _state(rows, filter: StockFilter.expired, query: 'gants');
      expect(s.filtered, isEmpty);
      expect(_state(rows, query: 'gants').filtered.map((r) => r.id), ['ok']);
    });
  });

  group('lots', () {
    BatchData lot({int? days, String status = 'active', int qty = 5}) =>
        BatchData.fromJson({
          'id': 'b',
          'product_id': 'p',
          'product_name': 'Gants',
          'supplier_name': 'Dental Plus',
          'batch_number': 'L1',
          if (days != null) 'expiry_date': _day(days),
          'status': status,
          'qty_on_hand': qty,
        });

    test('a lot that expires today is still usable today', () {
      final b = lot(days: 0);
      expect(b.isExpired, isFalse);
      expect(b.isNearExpiry, isTrue);
      expect(b.daysToExpiry, 0);
    });

    test('yesterday is expired, a month out is near, later is neither', () {
      expect(lot(days: -1).isExpired, isTrue);
      expect(lot(days: 30).isNearExpiry, isTrue);
      expect(lot(days: 31).isNearExpiry, isFalse);
    });

    test('no date means no expiry judgement at all', () {
      final b = lot();
      expect(b.daysToExpiry, isNull);
      expect(b.isExpired, isFalse);
      expect(b.isNearExpiry, isFalse);
    });

    test('quarantine and "nothing left" come from the server fields', () {
      expect(lot(status: 'quarantined').isQuarantined, isTrue);
      expect(lot(qty: 0).isEmpty, isTrue);
      expect(lot(qty: 3).isEmpty, isFalse);
    });

    test('a missing supplier does not break parsing', () {
      final b = BatchData.fromJson(const {'id': 'x', 'batch_number': 'L9'});
      expect(b.supplierName, '');
      expect(b.qtyOnHand, 0);
    });
  });
}
