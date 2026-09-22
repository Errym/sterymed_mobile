import 'dart:typed_data';

import '../../../../core/cache/cache.dart';
import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/storage/outbox/outbox_item.dart';
import '../../../../core/storage/outbox/outbox_operation.dart';
import '../../../../core/storage/outbox/outbox_store.dart';
import '../../../../core/sync/connectivity_service.dart';
import '../../../../core/sync/sync_status_cubit.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../../../../core/utils/logger.dart';
import '../datasources/cycle_remote_datasource.dart';
import '../models/control_test_data.dart';
import '../models/cycle_attachment_data.dart';
import '../models/cycle_data.dart';
import '../models/cycle_item_data.dart';
import '../models/cycle_release_data.dart';
import 'device_program_repository.dart';
import 'device_repository.dart';

class CycleRepository {
  final CycleRemoteDatasource _remote;
  final AppCache _cache;
  final DeviceRepository _devices;
  final DeviceProgramRepository _programs;
  final OutboxStore _outbox;
  final ConnectivityService _connectivity;
  final SyncStatusCubit _syncStatus;

  static const _enrichTimeout = Duration(seconds: 3);

  CycleRepository(
    this._remote,
    this._cache,
    this._devices,
    this._programs, {
    required OutboxStore outbox,
    required ConnectivityService connectivity,
    required SyncStatusCubit syncStatus,
  })  : _outbox = outbox,
        _connectivity = connectivity,
        _syncStatus = syncStatus;

  Future<List<CycleData>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<CycleData>>('cycles');
      if (cached != null) return cached;
    }
    final raw = await _remote.list();
    final enriched = await _enrichAll(raw);
    _cache.put('cycles', enriched);
    return enriched;
  }

  Future<CycleData> show(String id) async {
    final raw = await _remote.show(id);
    return _enrich(raw);
  }

  Future<CycleData> create(Map<String, dynamic> payload) async {
    final c = await _remote.create(payload);
    _cache.invalidate('cycles');
    _cache.invalidate('dashboard');
    return _enrich(c);
  }

  Future<CycleData> start(String id) => _submitTransition(
        operation: OutboxOperation.cycleTransition,
        endpoint: ApiEndpoints.cycleStart(id),
        cycleId: id,
        status: 'in_progress',
        online: () => _remote.start(id),
      );

  Future<CycleData> complete(String id) => _submitTransition(
        operation: OutboxOperation.cycleTransition,
        endpoint: ApiEndpoints.cycleComplete(id),
        cycleId: id,
        status: 'completed',
        online: () => _remote.complete(id),
      );

  Future<CycleData> submitForRelease(String id) => _submitTransition(
        operation: OutboxOperation.cycleTransition,
        endpoint: ApiEndpoints.cycleSubmit(id),
        cycleId: id,
        status: 'pending_release',
        online: () => _remote.submitForRelease(id),
      );

  /// Online-first with an offline outbox fallback, same pattern as
  /// StockRepository/LabelUsageRepository. The synthetic CycleData is
  /// intentionally minimal — cycle_detail_screen never reads its fields
  /// on a transition's success, it just triggers a refetch, which is
  /// the correct behavior offline too (shows cached state until the
  /// queued transition actually syncs).
  Future<CycleData> _submitTransition({
    required OutboxOperation operation,
    required String endpoint,
    required String cycleId,
    required String status,
    required Future<CycleData> Function() online,
  }) async {
    final isOnline = await _connectivity.isConnected;
    if (isOnline) {
      try {
        final result = await online();
        _cache.invalidate('cycles');
        _cache.invalidate('dashboard');
        return await _enrich(result);
      } on ApiException catch (e) {
        if (!e.isNetwork && !e.isTimeout) rethrow;
      }
    }

    final itemId = generateIdempotencyKey();
    await _outbox.enqueue(OutboxItem(
      id: itemId,
      operation: operation,
      endpoint: endpoint,
      method: 'POST',
      payload: const {},
      idempotencyKey: generateIdempotencyKey(),
      createdAt: DateTime.now(),
    ));
    _syncStatus.refreshNow();

    return CycleData(
      id: cycleId,
      number: '',
      status: status,
      deviceId: '',
      deviceName: '',
      createdAt: DateTime.now(),
    );
  }

  Future<CycleReleaseData> release(
    String id, {
    required String decision,
    String? reason,
  }) async {
    final isOnline = await _connectivity.isConnected;
    if (isOnline) {
      try {
        final r =
            await _remote.release(id, decision: decision, reason: reason);
        _cache.invalidate('cycles');
        _cache.invalidate('dashboard');
        return r;
      } on ApiException catch (e) {
        if (!e.isNetwork && !e.isTimeout) rethrow;
      }
    }

    final itemId = generateIdempotencyKey();
    await _outbox.enqueue(OutboxItem(
      id: itemId,
      operation: OutboxOperation.cycleTransition,
      endpoint: ApiEndpoints.cycleRelease(id),
      method: 'POST',
      payload: {
        'decision': decision,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
      idempotencyKey: generateIdempotencyKey(),
      createdAt: DateTime.now(),
    ));
    _syncStatus.refreshNow();

    return CycleReleaseData(
      id: itemId,
      cycleId: id,
      decision: decision == 'compliant'
          ? CycleReleaseDecision.compliant
          : CycleReleaseDecision.rejected,
      reason: reason,
      releasedAt: DateTime.now(),
    );
  }

  // ── Items ─────────────────────────────────────────────────────────────

  Future<List<CycleItemData>> listItems(String id) => _remote.listItems(id);

  Future<CycleItemData> addItem(String id, Map<String, dynamic> p) =>
      _remote.addItem(id, p);

  Future<void> deleteItem(String id, String itemId) =>
      _remote.deleteItem(id, itemId);

  // ── Control tests ─────────────────────────────────────────────────────

  Future<List<ControlTestData>> listControlTests(String id) =>
      _remote.listControlTests(id);

  Future<ControlTestData> addControlTest(
          String id, Map<String, dynamic> p) =>
      _remote.addControlTest(id, p);

  // ── Attachments ───────────────────────────────────────────────────────

  Future<List<CycleAttachmentData>> listAttachments(String id) =>
      _remote.listAttachments(id);

  Future<CycleAttachmentData> uploadAttachment({
    required String cycleId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) =>
      _remote.uploadAttachment(
        cycleId: cycleId,
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
      );

  Future<void> deleteAttachment(String id, String attachmentId) =>
      _remote.deleteAttachment(id, attachmentId);

  // ── Enrichment ────────────────────────────────────────────────────────

  Future<List<CycleData>> _enrichAll(List<CycleData> list) async {
    if (list.isEmpty) return list;

    // Load once, reuse for every cycle. Was: per-cycle lookup.
    final deviceMap = await _loadDeviceMap();
    final programCache = <String, Map<String, String>>{};

    final out = <CycleData>[];
    for (final c in list) {
      final deviceName = c.deviceName.isNotEmpty
          ? c.deviceName
          : (deviceMap[c.deviceId] ?? 'Appareil inconnu');

      String? programName = c.programName;
      if (programName == null &&
          c.deviceProgramId != null &&
          c.deviceProgramId!.isNotEmpty &&
          c.deviceId.isNotEmpty) {
        programCache.putIfAbsent(c.deviceId, () => {});
        // Load programmes for this device once.
        if (programCache[c.deviceId]!.isEmpty) {
          programCache[c.deviceId] = await _loadProgramMap(c.deviceId);
        }
        programName = programCache[c.deviceId]![c.deviceProgramId];
      }

      out.add(c.copyWithNames(
        deviceName: deviceName,
        programName: programName,
      ));
    }
    return out;
  }

  Future<CycleData> _enrich(CycleData c) async {
    var deviceName = c.deviceName;
    var programName = c.programName;

    if (deviceName.isEmpty && c.deviceId.isNotEmpty) {
      try {
        final devices = await _devices
            .list()
            .timeout(_enrichTimeout, onTimeout: () => []);
        final match = devices.where((d) => d.id == c.deviceId).toList();
        deviceName = match.isNotEmpty
            ? match.first.name
            : 'Appareil ${c.deviceId.substring(0, 6)}';
      } catch (e) {
        AppLogger.d('CycleRepository._enrich: device lookup failed: $e');
        deviceName = 'Appareil inconnu';
      }
    }

    if (programName == null &&
        c.deviceProgramId != null &&
        c.deviceProgramId!.isNotEmpty &&
        c.deviceId.isNotEmpty) {
      try {
        final programs = await _programs
            .list(c.deviceId)
            .timeout(_enrichTimeout, onTimeout: () => []);
        final match =
            programs.where((p) => p.id == c.deviceProgramId).toList();
        if (match.isNotEmpty) programName = match.first.name;
      } catch (e) {
        AppLogger.d('CycleRepository._enrich: program lookup failed: $e');
      }
    }

    return c.copyWithNames(
      deviceName: deviceName.isEmpty ? 'Appareil inconnu' : deviceName,
      programName: programName,
    );
  }

  Future<Map<String, String>> _loadDeviceMap() async {
    try {
      final devices =
          await _devices.list().timeout(_enrichTimeout, onTimeout: () => []);
      return {for (final d in devices) d.id: d.name};
    } catch (e) {
      AppLogger.d('CycleRepository._loadDeviceMap: $e');
      return const {};
    }
  }

  Future<Map<String, String>> _loadProgramMap(String deviceId) async {
    try {
      final programs = await _programs
          .list(deviceId)
          .timeout(_enrichTimeout, onTimeout: () => []);
      return {for (final p in programs) p.id: p.name};
    } catch (e) {
      AppLogger.d('CycleRepository._loadProgramMap: $e');
      return const {};
    }
  }
}
