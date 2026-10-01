import 'package:hive/hive.dart';
import '../secure_box.dart';
import '../secure_storage.dart';
import 'outbox_item.dart';
import 'outbox_status.dart';

class OutboxStore {
  static const _boxName = 'steriymed.outbox';
  final Box<dynamic>? _box;
  final String? Function()? _ownerScope;
  final bool recoveryRequired;

  OutboxStore(
    this._box, {
    this._ownerScope,
    this.recoveryRequired = false,
  });
  String? get currentOwner => _ownerScope?.call();
  bool get isScoped => _ownerScope != null;
  bool get available => _box != null && (!isScoped || currentOwner != null);
  Stream<BoxEvent> get changes => _box?.watch() ?? const Stream.empty();
  int get quarantineCount =>
      _box?.keys
          .where((key) => key.toString().startsWith('quarantine:'))
          .length ??
      0;

  static Future<OutboxStore> open({
    required SecureStorage secure,
    required String? Function() ownerScope,
  }) async {
    final opened = await SecureBox.open(_boxName, secure);
    return OutboxStore(
      opened.box,
      ownerScope: ownerScope,
      recoveryRequired: opened.recoveryRequired,
    );
  }

  bool _owned(OutboxItem item) =>
      !isScoped || currentOwner != null && item.ownerScope == currentOwner;

  Future<void> enqueue(OutboxItem item) async {
    if (!available || !_owned(item)) {
      throw StateError('Session ou stockage local indisponible.');
    }
    await _box!.put(item.id, item.toJson());
    await _box.flush();
  }

  List<OutboxItem> all() {
    final result = <OutboxItem>[];
    for (final key in _box?.keys ?? const []) {
      if (key.toString().startsWith('quarantine:')) continue;
      try {
        final item = OutboxItem.fromJson(
          (_box!.get(key) as Map).cast<String, dynamic>(),
        );
        if (_owned(item)) result.add(item);
      } catch (_) {
        /* Preserve unknown schema bytes without replaying them. */
      }
    }
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  List<OutboxItem> pending() =>
      all().where((i) => i.status == OutboxStatus.pending).toList();
  List<OutboxItem> manualReview() =>
      all().where((i) => i.status == OutboxStatus.manualReview).toList();
  int get pendingCount => pending().length;
  OutboxItem? find(String id) {
    for (final item in all()) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> update(OutboxItem item) => enqueue(item);
  Future<void> remove(String id) async {
    if (find(id) == null) return;
    await _box!.delete(id);
    await _box.flush();
  }

  Future<void> removeMany(Iterable<String> ids) async {
    final owned = all().map((item) => item.id).toSet();
    await _box?.deleteAll(ids.where(owned.contains));
    await _box?.flush();
  }

  Future<void> clear() => removeMany(all().map((item) => item.id));
}
