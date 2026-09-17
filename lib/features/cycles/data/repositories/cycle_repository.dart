import '../../../../core/cache/cache.dart';
import '../datasources/cycle_remote_datasource.dart';
import '../models/control_test_data.dart';
import '../models/cycle_attachment_data.dart';
import '../models/cycle_data.dart';
import '../models/cycle_item_data.dart';
import '../models/cycle_release_data.dart';

class CycleRepository {
  final CycleRemoteDatasource _remote;
  final AppCache _cache;

  CycleRepository(this._remote, this._cache);

  Future<List<CycleData>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<CycleData>>('cycles');
      if (cached != null) return cached;
    }
    final fresh = await _remote.list();
    _cache.put('cycles', fresh);
    return fresh;
  }

  Future<CycleData> show(String id) => _remote.show(id);

  Future<CycleData> create(Map<String, dynamic> payload) async {
    final c = await _remote.create(payload);
    _cache.invalidate('cycles');
    _cache.invalidate('dashboard');
    return c;
  }

  Future<CycleData> start(String id) async {
    final c = await _remote.start(id);
    _cache.invalidate('cycles');
    _cache.invalidate('dashboard');
    return c;
  }

  Future<CycleData> complete(String id) async {
    final c = await _remote.complete(id);
    _cache.invalidate('cycles');
    _cache.invalidate('dashboard');
    return c;
  }

  Future<CycleData> submitForRelease(String id) async {
    final c = await _remote.submitForRelease(id);
    _cache.invalidate('cycles');
    _cache.invalidate('dashboard');
    return c;
  }

  Future<CycleReleaseData> release(
    String id, {
    required String decision,
    String? reason,
  }) async {
    final r = await _remote.release(id, decision: decision, reason: reason);
    _cache.invalidate('cycles');
    _cache.invalidate('dashboard');
    return r;
  }

  Future<List<CycleItemData>> listItems(String id) => _remote.listItems(id);
  Future<CycleItemData> addItem(String id, Map<String, dynamic> p) =>
      _remote.addItem(id, p);
  Future<void> deleteItem(String id, String itemId) =>
      _remote.deleteItem(id, itemId);

  Future<List<ControlTestData>> listControlTests(String id) =>
      _remote.listControlTests(id);
  Future<ControlTestData> addControlTest(String id, Map<String, dynamic> p) =>
      _remote.addControlTest(id, p);

  Future<List<CycleAttachmentData>> listAttachments(String id) =>
      _remote.listAttachments(id);
  Future<CycleAttachmentData> uploadAttachment(
          String id, String filePath, String fileName) =>
      _remote.uploadAttachment(id, filePath, fileName);
  Future<void> deleteAttachment(String id, int mediaId) =>
      _remote.deleteAttachment(id, mediaId);
}
