import 'package:flutter/foundation.dart';

import '../config/env.dart';

class CrashReporter {
  Future<void> init() async {
    if (Env.sentryDsn.isEmpty) return;
    // Wire Sentry here later.
    if (kDebugMode) debugPrint('crash reporter: init skipped (empty DSN)');
  }

  void capture(Object error, StackTrace stack, {Map<String, Object?>? extras}) {
    if (kDebugMode) debugPrint('crash: $error');
    // Forward to Sentry later.
  }
}
