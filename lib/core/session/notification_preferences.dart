import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  NotificationPreferences._();

  static const _kPushNotifications = 'elecom.notifications.push_enabled';
  static const _kInAppNotifications = 'elecom.notifications.in_app_enabled';

  static Future<bool> isPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPushNotifications) ?? true;
  }

  static Future<bool> isInAppEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kInAppNotifications) ?? true;
  }

  static Future<void> setPushEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPushNotifications, value);
  }

  static Future<void> setInAppEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kInAppNotifications, value);
  }
}
