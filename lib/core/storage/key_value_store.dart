import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'secure_box.dart';
import 'secure_storage.dart';

class KeyValueStore {
  final Box<dynamic>? _box;
  final String? Function()? _ownerScope;
  final bool recoveryRequired;

  KeyValueStore(
    this._box, {
    this._ownerScope,
    this.recoveryRequired = false,
  });

  static Future<KeyValueStore> open(
    String name, {
    required SecureStorage secure,
    required String? Function() ownerScope,
  }) async {
    final opened = await SecureBox.open(name, secure);
    return KeyValueStore(
      opened.box,
      ownerScope: ownerScope,
      recoveryRequired: opened.recoveryRequired,
    );
  }

  int get quarantineCount =>
      _box?.keys
          .where((key) => key.toString().startsWith('quarantine:'))
          .length ??
      0;
  String? _key(String key) {
    if (_ownerScope == null) {
      return key; // Explicitly injected isolated test box.
    }
    final owner = _ownerScope();
    return owner == null ? null : jsonEncode(['v2', owner, key]);
  }

  dynamic get(String key) {
    final resolved = _key(key);
    return resolved == null ? null : _box?.get(resolved);
  }

  Future<void> set(String key, dynamic value) async {
    final resolved = _key(key);
    final box = _box;
    if (resolved == null || box == null) {
      throw StateError(
        'Stockage local indisponible. Vos données sont conservées.',
      );
    }
    await box.put(resolved, value);
    await box.flush();
  }

  Future<void> delete(String key) async {
    final resolved = _key(key);
    if (resolved == null || _box == null) return;
    await _box.delete(resolved);
    await _box.flush();
  }

  Future<void> clear() async {
    final box = _box;
    if (box == null) return;
    final owner = _ownerScope?.call();
    final keys = box.keys.where((key) {
      if (_ownerScope == null) return true;
      if (owner == null || key is! String || key.startsWith('quarantine:')) {
        return false;
      }
      try {
        final decoded = jsonDecode(key) as List;
        return decoded.length == 3 && decoded[1] == owner;
      } catch (_) {
        return false;
      }
    }).toList();
    await box.deleteAll(keys);
    await box.flush();
  }
}
