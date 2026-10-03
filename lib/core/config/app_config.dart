abstract final class AppConfig {
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  static const int defaultPageSize = 20;

  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const Duration scanCooldown = Duration(milliseconds: 400);

  static const int maxOutboxRetries = 5;

  /// How long the app may sit in the background before it asks the user to
  /// unlock it again. Shared clinic devices: short by default. A pilot can
  /// change it at build time with `--dart-define=LOCK_AFTER_MINUTES=5`.
  static const Duration lockAfter = Duration(
    minutes: int.fromEnvironment('LOCK_AFTER_MINUTES', defaultValue: 2),
  );
}
