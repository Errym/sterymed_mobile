import '../datasources/stock_remote_datasource.dart';
import '../models/stock_level_data.dart';
import '../models/stock_movement_data.dart';

class StockRepository {
  final StockRemoteDatasource _remote;
  StockRepository(this._remote);

  Future<List<StockLevelData>> listLevels({String? search}) =>
      _remote.listLevels(search: search);

  Future<StockMovementData> issue({
    required String batchId,
    required String locationId,
    required int qty,
    String? reason,
  }) =>
      _remote.issue(
        batchId: batchId,
        locationId: locationId,
        qty: qty,
        reason: reason,
      );

  Future<StockMovementData> adjust({
    required String batchId,
    required String locationId,
    required int qty,
    required String reason,
  }) =>
      _remote.adjust(
        batchId: batchId,
        locationId: locationId,
        qty: qty,
        reason: reason,
      );

  Future<StockMovementData> transfer({
    required String batchId,
    required String fromLocationId,
    required String toLocationId,
    required int qty,
    String? reason,
  }) =>
      _remote.transfer(
        batchId: batchId,
        fromLocationId: fromLocationId,
        toLocationId: toLocationId,
        qty: qty,
        reason: reason,
      );
}
