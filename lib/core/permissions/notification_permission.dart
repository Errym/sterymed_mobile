import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requested lazily — only when the user turns on the "Recevoir les
/// alertes" switch in Settings (`SettingsScreen`), never at app startup.
/// See docs/SECURITY.md's threat model for why: asking for a permission
/// the user hasn't chosen to use yet is both bad UX and an unnecessary
/// prompt to grant.
abstract final class NotificationPermission {
  static bool get _isWeb => kIsWeb;

  static Future<bool> isGranted() async {
    if (_isWeb) return false;
    return Permission.notification.isGranted;
  }

  static Future<bool> request() async {
    if (_isWeb) return false;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  static Future<bool> isPermanentlyDenied() async {
    if (_isWeb) return false;
    return Permission.notification.isPermanentlyDenied;
  }

  static Future<void> openSettings() async {
    if (_isWeb) return;
    await openAppSettings();
  }
}
