import 'package:get_it/get_it.dart';

import '../core/storage/key_value_store.dart';
import '../core/storage/outbox/outbox_store.dart';
import '../core/storage/secure_storage.dart';
import '../core/storage/session_store.dart';
import '../core/storage/token_storage.dart';

Future<void> registerStorage(GetIt getIt) async {
  final secure = SecureStorage();
  getIt.registerSingleton<SecureStorage>(secure);
  final session = SessionStore(secure);
  getIt.registerSingleton<TokenStorage>(TokenStorage(secure, session: session));
  getIt.registerSingleton<SessionStore>(session, dispose: (s) => s.dispose());

  final kv = await KeyValueStore.open(
    'steriymed.kv',
    secure: secure,
    ownerScope: () => session.scopeKey,
  );
  getIt.registerSingleton<KeyValueStore>(kv);

  final outbox = await OutboxStore.open(
    secure: secure,
    ownerScope: () => session.scopeKey,
  );
  getIt.registerSingleton<OutboxStore>(outbox);
}
