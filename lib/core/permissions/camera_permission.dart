import 'package:permission_handler/permission_handler.dart';

abstract final class CameraPermission {
  static Future<bool> isGranted() async => await Permission.camera.isGranted;

  static Future<bool> request() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<void> openSettings() => openAppSettings();
}
