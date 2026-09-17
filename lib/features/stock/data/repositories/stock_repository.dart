import '../../../../core/cache/cache.dart';
import '../datasources/stock_remote_datasource.dart';
import '../models/stock_level_data.dart';
import '../models/stock_movement_data.dart';

class StockRepository {
  final StockRemoteDatasource _remote;
  final AppCache _cache;

  StockRepository(this._remote, this._cache);

  Future<List<StockLevelData>> listLevels({
    String? search,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && (search == null || search.trim().isEmpty)) {
      final cached = _cache.get<List<StockLevelData>>('stock_levels');
      if (cached != null) return cached;
    }
    final fresh = await _remote.listLevels(search: search);
    if (search == null || search.trim().isEmpty) {
      _cache.put('stock_levels', fresh);
    }
    return fresh;
  }

  Future<StockMovementData> issue({
    required String batchId,
    required String locationId,
    required int qty,
    String? reason,
  }) async {
    final m = await _remote.issue(
      batchId: batchId,
      locationId: locationId,
      qty: qty,
      reason: reason,
    );
    _cache.invalidate('stock_levels');
    _cache.invalidate('dashboard');
    return m;
  }

  Future<StockMovementData> adjust({
    required String batchId,
    required String locationId,
    required int qty,
    required String reason,
  }) async {
    final m = await _remote.adjust(
      batchId: batchId,
      locationId: locationId,
      qty: qty,
      reason: reason,
    );
    _cache.invalidate('stock_levels');
    _cache.invalidate('dashboard');
    return m;
  }

  Future<StockMovementData> transfer({
    required String batchId,
    required String fromLocationId,
    required String toLocationId,
    required int qty,
    String? reason,
  }) async {
    final m = await _remote.transfer(
      batchId: batchId,
      fromLocationId: fromLocationId,
      toLocationId: toLocationId,
      qty: qty,
      reason: reason,
    );
    _cache.invalidate('stock_levels');
    _cache.invalidate('dashboard');
    return m;
  }
}
