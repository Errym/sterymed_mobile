import '../datasources/cycle_remote_datasource.dart';
import '../models/control_test_data.dart';
import '../models/cycle_attachment_data.dart';
import '../models/cycle_data.dart';
import '../models/cycle_item_data.dart';
import '../models/cycle_release_data.dart';

class CycleRepository {
  final CycleRemoteDatasource _remote;
  CycleRepository(this._remote);

  Future<List<CycleData>> list({String? cursor}) => _remote.list(cursor: cursor);
  Future<CycleData> show(String id) => _remote.show(id);
  Future<CycleData> create(Map<String, dynamic> payload) => _remote.create(payload);
  Future<CycleData> start(String id) => _remote.start(id);
  Future<CycleData> complete(String id) => _remote.complete(id);
  Future<CycleData> submitForRelease(String id) => _remote.submitForRelease(id);
  Future<CycleReleaseData> release(String id,
          {required String decision, String? reason}) =>
      _remote.release(id, decision: decision, reason: reason);

  Future<List<CycleItemData>> listItems(String id) => _remote.listItems(id);
  Future<CycleItemData> addItem(String id, Map<String, dynamic> payload) =>
      _remote.addItem(id, payload);
  Future<void> deleteItem(String id, String itemId) =>
      _remote.deleteItem(id, itemId);

  Future<List<ControlTestData>> listControlTests(String id) =>
      _remote.listControlTests(id);
  Future<ControlTestData> addControlTest(String id, Map<String, dynamic> payload) =>
      _remote.addControlTest(id, payload);

  Future<List<CycleAttachmentData>> listAttachments(String id) =>
      _remote.listAttachments(id);
  Future<CycleAttachmentData> uploadAttachment(
          String id, String filePath, String fileName) =>
      _remote.uploadAttachment(id, filePath, fileName);
  Future<void> deleteAttachment(String id, int mediaId) =>
      _remote.deleteAttachment(id, mediaId);
}