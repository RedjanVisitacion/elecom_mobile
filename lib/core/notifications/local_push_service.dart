import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LocalPushService {
  LocalPushService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: initSettings);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();
    final androidDetails = AndroidNotificationDetails(
      'elecom_general_notifications',
      'General Notifications',
      channelDescription: 'General notifications for ELECOM account activity.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        // Android will show the full text when expanded (prevents truncation).
      ),
    );
    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  static Future<void> showFromRemoteMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ?? (message.data['title'] ?? '').toString();
    final body =
        message.notification?.body ?? (message.data['body'] ?? '').toString();
    if (title.trim().isEmpty && body.trim().isEmpty) return;
    await show(
      id: message.hashCode,
      title: title.isEmpty ? 'ELECOM' : title,
      body: body,
    );
  }
}
