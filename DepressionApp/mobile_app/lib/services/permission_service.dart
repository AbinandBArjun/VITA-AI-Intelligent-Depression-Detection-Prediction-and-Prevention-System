import 'package:permission_handler/permission_handler.dart';
import 'package:usage_stats/usage_stats.dart';

class PermissionService {

  static Future<void> requestAllPermissions() async {

    // Camera
    await Permission.camera.request();

    // Notifications (Android 13+)
    await Permission.notification.request();

    // Usage Access (manual toggle)
    bool granted = await UsageStats.checkUsagePermission() ?? false;

    if (!granted) {
      await UsageStats.grantUsagePermission();
    }
  }
}