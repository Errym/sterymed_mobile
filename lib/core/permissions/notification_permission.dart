import 'package:permission_handler/permission_handler.dart';

abstract final class NotificationPermission {
  static Future<bool> request() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}
