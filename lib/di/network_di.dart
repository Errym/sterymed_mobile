import 'package:get_it/get_it.dart';

import '../core/network/dio_client.dart';
import '../core/network/network_info.dart';
import '../core/storage/token_storage.dart';

Future<void> registerNetwork(GetIt getIt) async {
  getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfo());
  getIt.registerLazySingleton<DioClient>(
    () => DioClient(getIt<TokenStorage>()),
  );
}
