import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/crash/crash_reporter.dart';
import 'di/di.dart';

Future<void> bootstrap(Widget Function() appBuilder) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await initDi();
  await getIt<CrashReporter>().init();
  runApp(appBuilder());
}
