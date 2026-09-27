import 'package:get_it/get_it.dart';

import '../core/router/app_router.dart';
import '../core/router/go_router_refresh_stream.dart';
import '../core/storage/session_store.dart';
import '../core/storage/token_storage.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';

Future<void> registerRouter(GetIt getIt) async {
  getIt.registerLazySingleton<AppRouter>(
    () => AppRouter(
      isAuthenticated: () => getIt<SessionStore>().hasSession,
      hasStoredToken: () async {
        final token = await getIt<TokenStorage>().read();
        return token != null && token.isNotEmpty;
      },
      // Re-evaluates `redirect` the instant AuthBloc emits (e.g. a
      // background AuthSessionExpired from a real 401), not just on the
      // next manual navigation — see go_router_refresh_stream.dart.
      refreshListenable: GoRouterRefreshStream(getIt<AuthBloc>().stream),
    ),
  );
}
