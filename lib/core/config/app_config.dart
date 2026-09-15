abstract final class AppConfig {
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  static const int defaultPageSize = 20;

  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const Duration scanCooldown = Duration(milliseconds: 400);

  static const int maxOutboxRetries = 5;
}
