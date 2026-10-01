import 'dart:convert';
import 'package:hive/hive.dart';
import 'secure_storage.dart';

/// Opens a new encrypted store. Unowned legacy bytes stay quarantined.
/// Missing keys/corrupt files never trigger deletion or a replacement key.
class SecureBox {
  final Box<dynamic>? box;
  final bool recoveryRequired;
  const SecureBox(this.box, {this.recoveryRequired = false});

  static Future<SecureBox> open(String legacyName, SecureStorage secure) async {
    final name = '$legacyName.v2';
    final keyName = '$name.encryption_key';
    try {
      var encoded = await secure.read(keyName);
      final exists = await Hive.boxExists(name);
      if (encoded == null && exists) {
        return const SecureBox(null, recoveryRequired: true);
      }
      if (encoded == null) {
        encoded = base64Encode(Hive.generateSecureKey());
        await secure.write(keyName, encoded);
      }
      final key = base64Decode(encoded);
      if (key.length != 32) {
        return const SecureBox(null, recoveryRequired: true);
      }
      final box = await Hive.openBox<dynamic>(
        name,
        encryptionCipher: HiveAesCipher(key),
        crashRecovery: false,
      );
      if (await Hive.boxExists(legacyName)) {
        final legacy = await Hive.openBox<dynamic>(
          legacyName,
          crashRecovery: false,
        );
        try {
          // Copy then flush BEFORE removing plaintext. Repeating after a crash
          // overwrites identical quarantine keys, without reassigning ownership.
          final keys = legacy.keys.toList(growable: false);
          for (final legacyKey in keys) {
            await box.put(
              'quarantine:${jsonEncode(legacyKey)}',
              legacy.get(legacyKey),
            );
          }
          await box.flush();
          await legacy.deleteAll(keys);
          await legacy.flush();
          await legacy.compact();
        } finally {
          await legacy.close();
        }
      }
      return SecureBox(box);
    } catch (_) {
      return const SecureBox(null, recoveryRequired: true);
    }
  }
}
