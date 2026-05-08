import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../features/elecom/data/elecom_mobile_api.dart';
import '../session/notification_preferences.dart';
import 'local_push_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Ignore when Firebase is unavailable on the device build.
  }
  await LocalPushService.showFromRemoteMessage(message);
}

class PushNotificationService {
  PushNotificationService._();

  static final ElecomMobileApi _api = ElecomMobileApi();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSub;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await LocalPushService.init();

    try {
      await Firebase.initializeApp();
    } catch (_) {
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    FirebaseMessaging.onMessage.listen((message) async {
      final enabled = await NotificationPreferences.isPushEnabled();
      if (!enabled) return;
      await LocalPushService.showFromRemoteMessage(message);
    });

    _tokenRefreshSub ??= _messaging.onTokenRefresh.listen((token) async {
      await _api.registerPushToken(token: token);
    });
  }

  static Future<void> syncForLoggedInUser() async {
    await init();
    final enabled = await NotificationPreferences.isPushEnabled();
    if (!enabled) {
      await disableForLoggedOutOrDisabled();
      return;
    }

    String? token;
    try {
      token = await _messaging.getToken();
    } catch (_) {
      token = null;
    }
    if (token == null || token.trim().isEmpty) return;
    await _api.registerPushToken(token: token);
  }

  static Future<void> disableForLoggedOutOrDisabled() async {
    await init();
    String? token;
    try {
      token = await _messaging.getToken();
    } catch (_) {
      token = null;
    }
    if (token != null && token.trim().isNotEmpty) {
      try {
        await _api.unregisterPushToken(token: token);
      } catch (_) {
        // Ignore network failures during logout.
      }
    }
  }
}
