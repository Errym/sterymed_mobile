import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/crash/crash_reporter.dart';
import 'core/storage/session_store.dart';
import 'core/sync/sync_status_cubit.dart';
import 'di/di.dart';

Future<void> bootstrap(Widget Function() appBuilder) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await initDi();
  await getIt<SessionStore>().load();
  await getIt<CrashReporter>().init();
  await getIt<SyncStatusCubit>().start();
  runApp(appBuilder());
}
