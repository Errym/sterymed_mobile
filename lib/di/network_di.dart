import 'package:get_it/get_it.dart';

import '../core/cache/cache.dart';
import '../core/network/dio_client.dart';
import '../core/network/network_info.dart';
import '../core/storage/outbox/outbox_store.dart';
import '../core/storage/outbox/sync_engine.dart';
import '../core/storage/token_storage.dart';
import '../core/storage/session_store.dart';
import '../core/sync/connectivity_service.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/bloc/auth_event.dart';

Future<void> registerNetwork(GetIt getIt) async {
  getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfo());
  getIt.registerLazySingleton<DioClient>(
    // Resolved lazily inside the closure, not at DioClient-construction
    // time — safe regardless of DI registration order, since AuthBloc is
    // only actually looked up the moment a real 401 happens, by which
    // point every registerXxx() has already run.
    () => DioClient(
      getIt<TokenStorage>(),
      session: getIt<SessionStore>(),
      onUnauthenticated: () => getIt<AuthBloc>().add(
        AuthSessionExpired(generation: getIt<SessionStore>().generation),
      ),
    ),
  );

  getIt.registerLazySingleton<ConnectivityService>(
    () => ConnectivityService(getIt<NetworkInfo>()),
  );

  getIt.registerLazySingleton<SyncEngine>(
    () => SyncEngine(
      getIt<OutboxStore>(),
      getIt<DioClient>().dio,
      // Without the session the engine cannot fence late results or refuse to
      // send while permissions are stale.
      session: getIt<SessionStore>(),
      // A confirmed write changes server state: drop stale list caches.
      onConfirmed: () => getIt<AppCache>().invalidateAll(),
    ),
  );
}
