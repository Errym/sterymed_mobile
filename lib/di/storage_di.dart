import 'package:get_it/get_it.dart';

import '../core/storage/key_value_store.dart';
import '../core/storage/outbox/outbox_store.dart';
import '../core/storage/secure_storage.dart';
import '../core/storage/session_store.dart';
import '../core/storage/token_storage.dart';

Future<void> registerStorage(GetIt getIt) async {
  final secure = SecureStorage();
  getIt.registerSingleton<SecureStorage>(secure);
  getIt.registerSingleton<TokenStorage>(TokenStorage(secure));
  getIt.registerSingleton<SessionStore>(SessionStore(secure));

  final kv = await KeyValueStore.open('steriymed.kv');
  getIt.registerSingleton<KeyValueStore>(kv);

  final outbox = await OutboxStore.open();
  getIt.registerSingleton<OutboxStore>(outbox);
}
