import 'package:get_it/get_it.dart';

import '../core/router/app_router.dart';
import '../core/storage/session_store.dart';
import '../core/storage/token_storage.dart';

Future<void> registerRouter(GetIt getIt) async {
  getIt.registerLazySingleton<AppRouter>(
    () => AppRouter(
      isAuthenticated: () => getIt<SessionStore>().hasSession,
      hasStoredToken: () async {
        final token = await getIt<TokenStorage>().read();
        return token != null && token.isNotEmpty;
      },
    ),
  );
}
