import 'package:hive/hive.dart';

import 'outbox_item.dart';
import 'outbox_status.dart';

class OutboxStore {
  static const _boxName = 'steriymed.outbox';
  final Box<dynamic> _box;

  OutboxStore(this._box);

  static Future<OutboxStore> open() async {
    final box = await Hive.openBox(_boxName);
    return OutboxStore(box);
  }

  Future<void> enqueue(OutboxItem item) => _box.put(item.id, item.toJson());

  List<OutboxItem> all() =>
      _box.values
          .map((e) => OutboxItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<OutboxItem> pending() =>
      all().where((i) => i.status == OutboxStatus.pending).toList();

  List<OutboxItem> manualReview() =>
      all().where((i) => i.status == OutboxStatus.manualReview).toList();

  int get pendingCount => pending().length;

  Future<void> update(OutboxItem item) => _box.put(item.id, item.toJson());

  Future<void> remove(String id) => _box.delete(id);

  Future<void> clear() => _box.clear();
}
