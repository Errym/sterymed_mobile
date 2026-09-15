import 'package:get_it/get_it.dart';

import 'core_di.dart';
import 'features_di.dart';
import 'network_di.dart';
import 'router_di.dart';
import 'storage_di.dart';

final getIt = GetIt.instance;

Future<void> initDi() async {
  await registerCore(getIt);
  await registerStorage(getIt);
  await registerNetwork(getIt);
  await registerRouter(getIt);
  await registerFeatures(getIt);
}
