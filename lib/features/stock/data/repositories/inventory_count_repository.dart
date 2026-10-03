import '../../../../core/cache/cache.dart';
import '../../../../core/network/cursor_page.dart';
import '../datasources/inventory_count_remote_datasource.dart';
import '../models/inventory_count_data.dart';

/// Inventory counts are never queued: they compare what a person sees on the
/// shelf with what the server holds right now, so each call goes to the server
/// and a failure is shown, not hidden.
class InventoryCountRepository {
  final InventoryCountRemoteDatasource _remote;
  final AppCache _cache;

  InventoryCountRepository(this._remote, this._cache);

  Future<CursorPage<InventoryCountSummary>> list({
    String? status,
    String? cursor,
  }) => _remote.list(status: status, cursor: cursor);

  Future<InventoryCountDetail> show(String id) => _remote.show(id);

  Future<InventoryCountDetail> open({
    required String locationId,
    String? note,
  }) => _remote.open(locationId: locationId, note: note);

  Future<InventoryCountLine> recordLine({
    required String countId,
    required String batchId,
    required int countedQty,
  }) => _remote.recordLine(
    countId: countId,
    batchId: batchId,
    countedQty: countedQty,
  );

  /// Closing writes the stock adjustments, so every stock view is stale after.
  Future<InventoryCountDetail> close(
    String id, {
    required bool acknowledgeUncounted,
  }) async {
    final closed = await _remote.close(
      id,
      acknowledgeUncounted: acknowledgeUncounted,
    );
    _cache.invalidate('stock_levels');
    _cache.invalidate('stock_sources');
    _cache.invalidate('dashboard');
    return closed;
  }

  Future<InventoryCountDetail> cancel(String id, {required String reason}) =>
      _remote.cancel(id, reason: reason);
}
