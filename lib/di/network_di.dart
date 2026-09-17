import 'package:get_it/get_it.dart';

import '../core/network/dio_client.dart';
import '../core/network/network_info.dart';
import '../core/storage/outbox/outbox_store.dart';
import '../core/storage/outbox/sync_engine.dart';
import '../core/storage/token_storage.dart';
import '../core/sync/connectivity_service.dart';

Future<void> registerNetwork(GetIt getIt) async {
  getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfo());
  getIt.registerLazySingleton<DioClient>(
    () => DioClient(getIt<TokenStorage>()),
  );

  getIt.registerLazySingleton<ConnectivityService>(
    () => ConnectivityService(getIt<NetworkInfo>()),
  );

  getIt.registerLazySingleton<SyncEngine>(
    () => SyncEngine(
      getIt<OutboxStore>(),
      getIt<DioClient>().dio,
    ),
  );
}
