import 'package:get_it/get_it.dart';

import '../core/analytics/analytics_service.dart';
import '../core/crash/crash_reporter.dart';

Future<void> registerCore(GetIt getIt) async {
  getIt.registerSingleton<AnalyticsService>(AnalyticsService());
  getIt.registerSingleton<CrashReporter>(CrashReporter());
}
