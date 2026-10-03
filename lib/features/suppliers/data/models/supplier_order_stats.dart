import '../../../purchases/data/models/purchase_order_data.dart';

/// What the orders say about one supplier: how many are still to come, how
/// many there have been, and when the last one was placed.
class SupplierOrderStats {
  final int total;
  final int open;
  final DateTime? lastOrderedAt;
  const SupplierOrderStats({
    this.total = 0,
    this.open = 0,
    this.lastOrderedAt,
  });

  /// Orders that are placed and not fully received: goods are expected.
  static bool isOpen(PurchaseOrderData o) =>
      o.status == 'ordered' || o.status == 'partially_received';

  /// One entry per supplier id found in [orders].
  static Map<String, SupplierOrderStats> bySupplier(
    Iterable<PurchaseOrderData> orders,
  ) {
    final out = <String, SupplierOrderStats>{};
    for (final o in orders) {
      final prev = out[o.supplierId] ?? const SupplierOrderStats();
      final when = o.orderedAt ?? o.createdAt;
      final last = prev.lastOrderedAt;
      out[o.supplierId] = SupplierOrderStats(
        total: prev.total + 1,
        open: prev.open + (isOpen(o) ? 1 : 0),
        lastOrderedAt: (last == null || when.isAfter(last)) ? when : last,
      );
    }
    return out;
  }
}
