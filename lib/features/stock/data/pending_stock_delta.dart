import '../../../core/storage/outbox/outbox_item.dart';
import '../../../core/storage/outbox/outbox_operation.dart';
import '../../../core/storage/outbox/outbox_status.dart';

/// The effect on the shelves of stock changes this phone has recorded but the
/// server has not confirmed yet.
///
/// The balance shown on screen is the last one the server confirmed; this is
/// kept apart from it on purpose. Adding the two would present a guess as a
/// fact (the queued change may still be refused), while ignoring it would let
/// the user issue the same units twice from the same phone. Screens show the
/// confirmed balance and the pending change side by side, and bound what can
/// be taken by the sum of the two.
class PendingStockDelta {
  final Map<String, int> _byPair;

  const PendingStockDelta._(this._byPair);

  static const empty = PendingStockDelta._({});

  /// Changes still on their way: waiting, in flight, or of unknown outcome.
  /// Refused ones (conflict, validation) no longer count; they are shown as
  /// stuck work in the queue.
  static bool _counts(OutboxStatus s) =>
      s == OutboxStatus.pending ||
      s == OutboxStatus.syncing ||
      s == OutboxStatus.authBlocked ||
      s == OutboxStatus.unknownOutcome;

  factory PendingStockDelta.fromItems(Iterable<OutboxItem> items) {
    final map = <String, int>{};
    void add(String? batch, String? location, int qty) {
      if (batch == null || location == null) return;
      final key = '$batch|$location';
      map[key] = (map[key] ?? 0) + qty;
    }

    for (final item in items) {
      if (!_counts(item.status)) continue;
      final p = item.payload;
      final qty = (p['qty'] as num?)?.toInt() ?? 0;
      switch (item.operation) {
        case OutboxOperation.stockIssue:
          add(p['batch_id']?.toString(), p['location_id']?.toString(), -qty);
        case OutboxOperation.stockAdjust:
          add(p['batch_id']?.toString(), p['location_id']?.toString(), qty);
        case OutboxOperation.stockTransfer:
          add(p['batch_id']?.toString(), p['from_location_id']?.toString(), -qty);
          add(p['batch_id']?.toString(), p['to_location_id']?.toString(), qty);
        case OutboxOperation.goodsReceipt:
        // A queued receipt has no batch id yet (the server creates the lot),
        // so it cannot be attributed to a row; it only shows in the queue.
        case OutboxOperation.labelUsage:
        case OutboxOperation.cycleTransition:
          break;
      }
    }
    return PendingStockDelta._(map);
  }

  /// Pending units for one (batch, location): negative when more is going out
  /// than coming in.
  int forPair(String? batchId, String locationId) =>
      _byPair['${batchId ?? ''}|$locationId'] ?? 0;

  bool get isEmpty => _byPair.values.every((v) => v == 0);
}
