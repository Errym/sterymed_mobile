import '../../../../core/cache/cache.dart';
import '../datasources/device_program_remote_datasource.dart';
import '../models/device_program_data.dart';

class DeviceProgramRepository {
  final DeviceProgramRemoteDatasource _remote;
  final AppCache _cache;

  DeviceProgramRepository(this._remote, this._cache);

  Future<List<DeviceProgramData>> list(
    String deviceId, {
    bool forceRefresh = false,
  }) async {
    final key = 'device_programs:$deviceId';
    if (!forceRefresh) {
      final cached = _cache.get<List<DeviceProgramData>>(key);
      if (cached != null) return cached;
    }
    final fresh = await _remote.list(deviceId);
    _cache.put(key, fresh);
    return fresh;
  }

  Future<DeviceProgramData> create({
    required String deviceId,
    required String name,
    required int temperatureCelsius,
    required int plateauMinutes,
    bool isActive = true,
  }) async {
    final p = await _remote.create(
      deviceId: deviceId,
      name: name,
      temperatureCelsius: temperatureCelsius,
      plateauMinutes: plateauMinutes,
      isActive: isActive,
    );
    _cache.invalidate('device_programs:$deviceId');
    return p;
  }

  Future<DeviceProgramData> update({
    required String deviceId,
    required String programId,
    String? name,
    int? temperatureCelsius,
    int? plateauMinutes,
    bool? isActive,
  }) async {
    final p = await _remote.update(
      deviceId: deviceId,
      programId: programId,
      name: name,
      temperatureCelsius: temperatureCelsius,
      plateauMinutes: plateauMinutes,
      isActive: isActive,
    );
    _cache.invalidate('device_programs:$deviceId');
    return p;
  }

  Future<void> destroy({
    required String deviceId,
    required String programId,
  }) async {
    await _remote.destroy(deviceId: deviceId, programId: programId);
    _cache.invalidate('device_programs:$deviceId');
  }
}
