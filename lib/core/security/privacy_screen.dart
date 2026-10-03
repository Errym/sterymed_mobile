import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hides the app's content in the recent-apps switcher and blocks screenshots
/// (Android `FLAG_SECURE`), so patient references are not left visible on a
/// shared device.
///
/// On by default. A QA build that has to be screen-recorded as acceptance
/// evidence is built with `--dart-define=PRIVACY_SCREEN=false`; the setting is
/// a build-time one on purpose, so a user cannot switch it off.
abstract final class PrivacyScreen {
  static const _channel = MethodChannel('steriymed/privacy');
  static const enabledByBuild =
      bool.fromEnvironment('PRIVACY_SCREEN', defaultValue: true);

  static Future<void> apply({bool? enabled}) async {
    final on = enabled ?? enabledByBuild;
    try {
      await _channel.invokeMethod<void>('setSecure', on);
    } on MissingPluginException {
      // Not on a platform that implements it (tests, desktop): nothing to hide.
    } on PlatformException catch (e) {
      debugPrint('PrivacyScreen: ${e.code}');
    }
  }
}
