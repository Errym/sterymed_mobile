import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/bootstrap/stock_seed_check.dart';
import 'core/config/env.dart';
import 'core/config/build_info.dart';
import 'core/crash/crash_reporter.dart';
import 'core/storage/session_store.dart';
import 'core/sync/sync_status_cubit.dart';
import 'di/di.dart';
import 'features/stock/data/repositories/stock_repository.dart';

Future<void> bootstrap(Widget Function() appBuilder) async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertSecureTransportInProduction();
  await Hive.initFlutter();
  await initDi();
  await getIt<SessionStore>().load();
  runApp(appBuilder());
  unawaited(BuildInfo.initialize().catchError((Object _) {}));
  unawaited(getIt<CrashReporter>().init().catchError((Object _) {}));
  unawaited(getIt<SyncStatusCubit>().start());
  unawaited(
    checkStockSeedStatus(
      session: getIt<SessionStore>(),
      stockRepository: getIt<StockRepository>(),
      crashReporter: getIt<CrashReporter>(),
    ),
  );
}
