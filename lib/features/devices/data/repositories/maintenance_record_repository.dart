import '../../../../core/cache/cache.dart';
import '../datasources/maintenance_record_datasource.dart';
import '../models/maintenance_record_data.dart';

class MaintenanceRecordRepository {
  final MaintenanceRecordDatasource _remote;
  final AppCache _cache;

  MaintenanceRecordRepository(this._remote, this._cache);

  Future<List<MaintenanceRecordData>> list(
    String deviceId, {
    bool forceRefresh = false,
  }) async {
    final key = 'device_maintenance:$deviceId';
    if (!forceRefresh) {
      final cached = _cache.get<List<MaintenanceRecordData>>(key);
      if (cached != null) return cached;
    }
    final fresh = await _remote.list(deviceId);
    _cache.put(key, fresh);
    return fresh;
  }

  Future<MaintenanceRecordData> create({
    required String deviceId,
    required String kind,
    String? technician,
    required DateTime performedAt,
    DateTime? nextDueAt,
    String? description,
  }) async {
    final record = await _remote.create(
      deviceId: deviceId,
      kind: kind,
      technician: technician,
      performedAt: performedAt,
      nextDueAt: nextDueAt,
      description: description,
    );
    _cache.invalidate('device_maintenance:$deviceId');
    return record;
  }
}
