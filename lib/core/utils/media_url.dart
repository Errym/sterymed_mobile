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
