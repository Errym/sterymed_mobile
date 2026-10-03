import 'dart:math';

import '../data/models/stock_level_data.dart';
import '../data/pending_stock_delta.dart';

/// The rules a stock movement must satisfy before it is worth sending. The
/// server enforces them again (it is the authority, and a second operator may
/// have taken the stock in the meantime); checking here gives the user the
/// reason immediately and keeps a phone from queueing something doomed.
abstract final class StockRules {
  /// Units that can still be taken from this row: the confirmed balance plus
  /// what this phone already has on its way in or out.
  static int available(StockLevelData row, PendingStockDelta pending) =>
      max(0, row.qty + pending.forPair(row.batchId, row.locationId));

  /// Why [text] cannot be taken from a row with [available] units, or null.
  static String? takeQtyError(String? text, int available) {
    final t = text?.trim() ?? '';
    if (t.isEmpty) return 'Requis.';
    final n = int.tryParse(t);
    if (n == null || n <= 0) return 'Entrez un nombre entier positif.';
    if (n > available) {
      return available == 0
          ? 'Plus rien de disponible à cet emplacement.'
          : 'Maximum $available : c\'est ce qui est disponible ici.';
    }
    return null;
  }

  /// Using up expired stock is allowed (it has to leave the shelves) but never
  /// silently: the reason is mandatory, like on the server.
  static bool issueNeedsReason(StockLevelData row) => row.isExpired;

  /// Why a signed adjustment cannot be applied, or null. A positive one adds
  /// to any place; a negative one can only remove what is there.
  static String? adjustQtyError(String? text, {int? available}) {
    final t = text?.trim() ?? '';
    if (t.isEmpty) return 'Requis.';
    final n = int.tryParse(t);
    if (n == null || n <= 0) return 'Entrez un nombre entier positif.';
    if (available != null && n > available) {
      return available == 0
          ? 'Plus rien de disponible à cet emplacement.'
          : 'Maximum $available : c\'est ce qui est disponible ici.';
    }
    return null;
  }

  /// Rows sorted the way people pick: product name, then the soonest expiry
  /// first (first expired, first out), then place.
  static List<StockLevelData> sorted(Iterable<StockLevelData> rows) {
    final list = rows.toList();
    list.sort((a, b) {
      final byName = a.productName.toLowerCase().compareTo(
        b.productName.toLowerCase(),
      );
      if (byName != 0) return byName;
      final ae = a.expiryDate;
      final be = b.expiryDate;
      if (ae != null && be != null) {
        final byExpiry = ae.compareTo(be);
        if (byExpiry != 0) return byExpiry;
      } else if (ae != null) {
        return -1;
      } else if (be != null) {
        return 1;
      }
      return a.locationName.toLowerCase().compareTo(b.locationName.toLowerCase());
    });
    return list;
  }

  /// Case-insensitive match on product, reference, lot or place.
  static bool matches(StockLevelData row, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return row.productName.toLowerCase().contains(q) ||
        row.reference.toLowerCase().contains(q) ||
        (row.batchNumber ?? '').toLowerCase().contains(q) ||
        row.locationName.toLowerCase().contains(q);
  }
}
