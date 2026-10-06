import 'package:elecom_mobile/core/notifications/local_push_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'polling and remote push use one persistent server notification ID',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({});
      final shown = <int>[];
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'show') {
              shown.add((call.arguments as Map)['id'] as int);
            }
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await LocalPushService.show(
        id: 41,
        title: 'Approved',
        body: 'Your filing was approved.',
      );
      await LocalPushService.showFromRemoteMessage(
        const RemoteMessage(
          data: {
            'notification_id': '41',
            'title': 'Approved',
            'body': 'Your filing was approved.',
          },
        ),
      );
      expect(shown, [41]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('elecom.notifications.delivered_ids'), ['41']);
    },
  );
}
