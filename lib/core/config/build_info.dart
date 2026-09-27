// Kept in sync with pubspec.yaml's `version:` field manually -- no
// package_info_plus-style dependency reads it at build time, so bumping
// one without the other silently shows a stale version in the About/
// Settings screen. Update both together.
abstract final class BuildInfo {
  static const String version = '0.2.0';
  static const String buildNumber = '1';
  static String get fullVersion => '$version ($buildNumber)';
}
