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

  /// Fails fast at boot rather than silently shipping a production build
  /// pointed at a plaintext backend — see docs/SECURITY.md "Known gaps".
  /// `apiBaseUrl`'s `http://` default exists only for local emulator/
  /// device testing; a real production build must always pass
  /// `--dart-define=API_BASE_URL=https://...` alongside `ENV=production`.
  static void assertSecureTransportInProduction() =>
      checkSecureTransport(isProduction: isProduction, apiBaseUrl: apiBaseUrl);

  static void checkSecureTransport({
    required bool isProduction,
    required String apiBaseUrl,
  }) {
    if (isProduction && !apiBaseUrl.startsWith('https://')) {
      throw StateError(
        'Env.apiBaseUrl must be https:// in production (got: $apiBaseUrl). '
        'Pass --dart-define=API_BASE_URL=https://... at build time.',
      );
    }
  }
}
