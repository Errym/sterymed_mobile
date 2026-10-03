abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  /// [apiBaseUrl] with any trailing slash stripped, so callers that
  /// concatenate a path (e.g. `'${Env.resolvedApiBaseUrl}/v1/...'`) can't
  /// accidentally produce a `//v1/...` path. [apiBaseUrl] itself is kept
  /// as-is for backward compat.
  static String get resolvedApiBaseUrl => stripTrailingSlash(apiBaseUrl);

  static String stripTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  static const environment = String.fromEnvironment('ENV', defaultValue: 'dev');

  static const sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  // Firebase Cloud Messaging (push notifications). All four must be given at
  // build time (`--dart-define`); without them push is reported as not
  // configured and nothing Firebase-related starts.
  static const firebaseApiKey =
      String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
  static const firebaseAppId =
      String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
  static const firebaseMessagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
  static const firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
  static const pushConfigured = firebaseApiKey != '' &&
      firebaseAppId != '' &&
      firebaseMessagingSenderId != '' &&
      firebaseProjectId != '';

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
