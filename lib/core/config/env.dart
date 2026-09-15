abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  static const environment = String.fromEnvironment('ENV', defaultValue: 'dev');

  static const sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  static bool get isDev => environment == 'dev';
  static bool get isStaging => environment == 'staging';
  static bool get isProduction => environment == 'production';
}
