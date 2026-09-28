import 'package:package_info_plus/package_info_plus.dart';

/// Version/build number shown to the user (About/Settings screens).
///
/// [_fallbackVersion]/[_fallbackBuildNumber] are only ever seen before
/// [initialize] has run (or on a platform where package_info_plus has no
/// data). Once [initialize] completes, the values come from the platform's
/// package info, which Flutter's own build tooling derives from
/// `pubspec.yaml`'s `version:` field on every build -- so a version bump
/// there is reflected automatically, with no manual edit here.
abstract final class BuildInfo {
  static const String _fallbackVersion = '0.2.0';
  static const String _fallbackBuildNumber = '1';

  static String _version = _fallbackVersion;
  static String _buildNumber = _fallbackBuildNumber;

  static String get version => _version;
  static String get buildNumber => _buildNumber;
  static String get fullVersion => '$version ($buildNumber)';

  /// Populates [version]/[buildNumber] from the platform's package info.
  /// Call once at app startup, before the About/Settings screens can be
  /// reached. Safe to skip (e.g. in tests) -- callers keep getting the
  /// fallback values above.
  static Future<void> initialize() async {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isNotEmpty) _version = info.version;
    if (info.buildNumber.isNotEmpty) _buildNumber = info.buildNumber;
  }
}
