import 'package:flutter/foundation.dart';

/// The backend returns pre-signed MinIO URLs with the Docker-internal
/// hostname `minio`. Browsers outside the Docker network can't resolve it,
/// so images and PDFs fail to load on Flutter Web.
///
/// This helper rewrites the host to `localhost` (where MinIO is exposed
/// via docker-compose port mapping). On native platforms the URL is used
/// as-is because mobile devices also can't reach `minio` directly — they
/// hit the API base URL instead.
abstract final class MediaUrl {
  static String resolve(String raw) {
    if (raw.isEmpty) return raw;

    // NOT gated behind kDebugMode (a previous pass added that gate for
    // generic "no dev-only http rewriting in release" hygiene, but that
    // was wrong here — see docs/BACKEND_BUGS.md#bug-010, still open and
    // blocking as of that doc's last update). The backend's presigned
    // URLs for exports and cycle/label attachments come back pointed at
    // the Docker-internal `minio` hostname regardless of build mode —
    // this isn't a dev convenience to strip, it's a live, currently-
    // required interop fix. Disabling it in release breaks every
    // export/attachment download in the exact release build this app
    // ships. Revisit only once BUG-010 is actually fixed backend-side.

    // Rewrite minio:9000 -> localhost:9000 on web so the browser can
    // reach the MinIO container via the exposed port.
    if (kIsWeb) {
      return raw
          .replaceFirst('http://minio:9000', 'http://localhost:9000')
          .replaceFirst('https://minio:9000', 'https://localhost:9000')
          .replaceFirst('http://minio', 'http://localhost')
          .replaceFirst('https://minio', 'https://localhost');
    }

    // On native, the same rewrite works because Android/iOS simulators
    // hit 10.0.2.2 or the LAN IP. Rewrite to the same host as the API
    // base URL for consistency.
    return raw
        .replaceFirst('http://minio:9000', 'http://10.0.2.2:9000')
        .replaceFirst('https://minio:9000', 'https://10.0.2.2:9000');
  }
}
