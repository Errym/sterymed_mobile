import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Cross-platform camera permission helper.
///
/// On Flutter Web, camera access is handled by the browser when the
/// <input capture> is triggered — asking via permission_handler does
/// nothing (the plugin is a no-op on web). We short-circuit and return
/// true so the picker runs.
///
/// On iOS/Android, we actually check and request the native permission.
abstract final class CameraPermission {
  static bool get _isWeb => kIsWeb;

  static Future<bool> isGranted() async {
    if (_isWeb) return true;
    return Permission.camera.isGranted;
  }

  static Future<bool> request() async {
    if (_isWeb) return true;
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> isPermanentlyDenied() async {
    if (_isWeb) return false;
    return Permission.camera.isPermanentlyDenied;
  }

  static Future<void> openSettings() async {
    if (_isWeb) return;
    await openAppSettings();
  }
}
