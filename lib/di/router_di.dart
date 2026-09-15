import 'package:get_it/get_it.dart';

import '../core/router/app_router.dart';
import '../core/storage/session_store.dart';

Future<void> registerRouter(GetIt getIt) async {
  getIt.registerLazySingleton<AppRouter>(
    () => AppRouter(isAuthenticated: () => getIt<SessionStore>().hasSession),
  );
}
