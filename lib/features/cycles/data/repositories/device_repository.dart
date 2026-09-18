import 'dart:async';

import '../../../../core/cache/cache.dart';
import '../datasources/device_remote_datasource.dart';
import '../models/device_data.dart';

/// Repository for the cycle-detail device picker.
///
/// Emits on [changes] whenever a device is created, updated, or deleted —
/// so any open screen holding a stale list can refresh itself.
class DeviceRepository {
  static const _cacheKey = 'devices';

  final DeviceRemoteDatasource _remote;
  final AppCache _cache;

  final _changes = StreamController<void>.broadcast();

  DeviceRepository(this._remote, this._cache);

  /// Broadcast stream — fires whenever the underlying device list changes.
  Stream<void> get changes => _changes.stream;

  Future<List<DeviceData>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<DeviceData>>(_cacheKey);
      if (cached != null && cached.isNotEmpty) return cached;
    }
    final fresh = await _remote.list();
    if (fresh.isNotEmpty) {
      _cache.put(_cacheKey, fresh);
    } else {
      _cache.invalidate(_cacheKey);
    }
    return fresh;
  }

  Future<DeviceData> create({
    required String siteId,
    required String name,
    required String serialNumber,
    required String kind,
    String? manufacturer,
    String? model,
    String? notes,
  }) async {
    final d = await _remote.create(
      siteId: siteId,
      name: name,
      serialNumber: serialNumber,
      kind: kind,
      manufacturer: manufacturer,
      model: model,
      notes: notes,
    );
    _cache.invalidate(_cacheKey);
    _cache.invalidateAll();
    _changes.add(null); // notify listeners
    return d;
  }

  /// Explicit cache invalidation — call this when the user navigates back
  /// from the Devices screen and you want the next `list()` to hit the API.
  void invalidateCache() {
    _cache.invalidate(_cacheKey);
  }

  void dispose() {
    _changes.close();
  }
}
