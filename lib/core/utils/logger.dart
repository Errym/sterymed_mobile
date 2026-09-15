import 'package:flutter/foundation.dart';

abstract final class AppLogger {
  static void d(String message) {
    if (kDebugMode) debugPrint(message);
  }

  static void e(String message, {Object? error}) {
    if (kDebugMode) debugPrint('ERROR: $message ${error ?? ''}');
  }
}