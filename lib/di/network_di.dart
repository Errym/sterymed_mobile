import '../core/storage/key_value_store.dart';
import '../core/push/push_gateway.dart';
import '../core/push/push_remote_datasource.dart';
import '../core/push/push_service.dart';
import 'dart:async';

import 'package:get_it/get_it.dart';

import '../core/cache/cache.dart';
import '../core/network/dio_client.dart';
import '../core/config/app_config.dart';
import '../core/network/network_info.dart';
import '../core/security/inactivity_lock.dart';
import '../core/version/version_gate.dart';
import '../core/storage/outbox/outbox_store.dart';
import '../core/storage/outbox/sync_engine.dart';
import '../core/storage/token_storage.dart';
import '../core/storage/session_store.dart';
import '../core/sync/connectivity_service.dart';
import '../features/auth/data/repositories/auth_repository.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/bloc/auth_event.dart';

Future<void> registerNetwork(GetIt getIt) async {
  // A 403 may mean the user's role changed on the server: re-read /me, at most
  // once per 30 s and never concurrently (the /me call itself may be refused).
  var refreshingPermissions = false;
  DateTime? lastPermissionRefresh;
  Future<void> refreshPermissions() async {
    final last = lastPermissionRefresh;
    if (refreshingPermissions ||
        (last != null &&
            DateTime.now().difference(last) < const Duration(seconds: 30))) {
      return;
    }
    refreshingPermissions = true;
    lastPermissionRefresh = DateTime.now();
    try {
      await getIt<AuthRepository>().restoreSession();
    } catch (_) {
      // Offline or refused: the periodic refresh will try again.
    } finally {
      refreshingPermissions = false;
    }
  }

  getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfo());
  getIt.registerLazySingleton<VersionGate>(() => VersionGate());
  getIt.registerLazySingleton<InactivityLock>(
    () => InactivityLock(
      timeout: AppConfig.lockAfter,
      isSignedIn: () => getIt<SessionStore>().hasSession,
      authenticator: LocalDeviceAuthenticator(),
      // A device with no screen lock cannot be asked anything: sign out
      // (unsent work stays in the user's own encrypted storage).
      onNoDeviceLock: () => getIt<AuthBloc>().add(const AuthLogoutRequested()),
    ),
  );
  getIt.registerLazySingleton<DioClient>(
    // Resolved lazily inside the closure, not at DioClient-construction
    // time — safe regardless of DI registration order, since AuthBloc is
    // only actually looked up the moment a real 401 happens, by which
    // point every registerXxx() has already run.
    () => DioClient(
      getIt<TokenStorage>(),
      session: getIt<SessionStore>(),
      versionGate: getIt<VersionGate>(),
      onUnauthenticated: () => getIt<AuthBloc>().add(
        AuthSessionExpired(generation: getIt<SessionStore>().generation),
      ),
      onForbidden: () => unawaited(refreshPermissions()),
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

  // Push notifications: the gateway is the only thing that touches Firebase.
  getIt.registerLazySingleton<PushGateway>(FirebasePushGateway.new);
  getIt.registerLazySingleton<PushRemoteDatasource>(
    () => PushRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<PushService>(
    () => PushService(
      gateway: getIt<PushGateway>(),
      remote: getIt<PushRemoteDatasource>(),
      prefs: PushPreference(getIt<KeyValueStore>()),
      session: getIt<SessionStore>(),
    ),
  );
}
