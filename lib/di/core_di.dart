import 'package:get_it/get_it.dart';

import '../core/analytics/analytics_service.dart';
import '../core/cache/cache.dart';
import '../core/crash/crash_reporter.dart';
import '../core/storage/outbox/outbox_store.dart';
import '../core/storage/session_store.dart';
import '../features/auth/data/repositories/auth_repository.dart';
import '../core/storage/outbox/sync_engine.dart';
import '../core/sync/connectivity_service.dart';
import '../core/sync/sync_status_cubit.dart';

Future<void> registerCore(GetIt getIt) async {
  getIt.registerSingleton<AnalyticsService>(AnalyticsService());
  getIt.registerSingleton<CrashReporter>(CrashReporter());
  getIt.registerSingleton<AppCache>(
    AppCache(ownerScope: () => getIt<SessionStore>().scopeKey),
  );

  getIt.registerLazySingleton<SyncStatusCubit>(
    () => SyncStatusCubit(
      store: getIt<OutboxStore>(),
      engine: getIt<SyncEngine>(),
      connectivity: getIt<ConnectivityService>(),
      session: getIt<SessionStore>(),
      refreshSession: () => getIt<AuthRepository>().restoreSession(),
      observeLifecycle: true,
    ),
  );
}
