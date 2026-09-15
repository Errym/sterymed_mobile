import 'package:hive_flutter/hive_flutter.dart';

class KeyValueStore {
  final Box<dynamic> _box;

  KeyValueStore(this._box);

  static Future<KeyValueStore> open(String name) async {
    final box = await Hive.openBox(name);
    return KeyValueStore(box);
  }

  dynamic get(String key) => _box.get(key);
  Future<void> set(String key, dynamic value) => _box.put(key, value);
  Future<void> delete(String key) => _box.delete(key);
  Future<void> clear() => _box.clear();
}
