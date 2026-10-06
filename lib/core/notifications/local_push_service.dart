import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalPushService {
  LocalPushService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Future<void> _deliveryQueue = Future.value();

  static Future<void> init({bool requestPermission = true}) async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: initSettings);
    if (requestPermission) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'elecom_general_notifications',
            'General Notifications',
            description: 'ELECOM account and candidate filing updates.',
            importance: Importance.max,
          ),
        );
    _initialized = true;
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    final previous = _deliveryQueue;
    final completed = Completer<void>();
    _deliveryQueue = completed.future;
    await previous;
    try {
      await _show(id: id, title: title, body: body);
    } finally {
      completed.complete();
    }
  }

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final delivered =
        prefs.getStringList('elecom.notifications.delivered_ids') ?? [];
    if (delivered.contains('$id')) return;
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
    await prefs.setStringList(
      'elecom.notifications.delivered_ids',
      [...delivered, '$id'].reversed.take(400).toList().reversed.toList(),
    );
  }

  static Future<void> showFromRemoteMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ?? (message.data['title'] ?? '').toString();
    final body =
        message.notification?.body ?? (message.data['body'] ?? '').toString();
    if (title.trim().isEmpty && body.trim().isEmpty) return;
    await show(
      id:
          int.tryParse((message.data['notification_id'] ?? '').toString()) ??
          message.hashCode,
      title: title.isEmpty ? 'ELECOM' : title,
      body: body,
    );
  }
}
