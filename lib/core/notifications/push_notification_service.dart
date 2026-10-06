import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/elecom/data/elecom_mobile_api.dart';
import '../session/notification_preferences.dart';
import '../session/user_session.dart';
import 'local_push_service.dart';
import 'notification_center_store.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  if (prefs.getBool('elecom.notifications.push_enabled') == false) return;
  final recipient = (message.data['student_id'] ?? '').toString();
  if (recipient.isNotEmpty &&
      recipient != prefs.getString('elecom.notifications.push_student')) {
    return;
  }
  // Firebase displays notification payloads itself; our server uses data messages.
  if (message.notification != null) return;
  await LocalPushService.init(requestPermission: false);
  await LocalPushService.showFromRemoteMessage(message);
}

class PushNotificationService {
  PushNotificationService._();

  static final ElecomMobileApi _api = ElecomMobileApi();
  static bool _initialized = false;
  static bool _ready = false;
  static String? _registeredToken;
  static String? _registeredStudent;
  static StreamSubscription<String>? _tokenRefreshSub;
  static final _lifecycle = _PushLifecycle();

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await LocalPushService.init();
      await Firebase.initializeApp();
      _ready = true;
    } catch (_) {
      debugPrint(
        'Push unavailable: check Android Firebase configuration and notification permission.',
      );
      return;
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    WidgetsBinding.instance.addObserver(_lifecycle);

    FirebaseMessaging.onMessage.listen((message) async {
      // Inbox updates are independent of the system-notification preference.
      unawaited(NotificationCenterStore.refresh());
      final recipient = (message.data['student_id'] ?? '').toString();
      if (recipient.isNotEmpty && recipient != UserSession.studentId) return;
      if (!await NotificationPreferences.isPushEnabled()) return;
      try {
        await LocalPushService.showFromRemoteMessage(message);
      } catch (_) {
        // A denied Android permission must not prevent inbox updates.
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      unawaited(NotificationCenterStore.refresh());
    });
    _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) {
      _registeredToken = null;
      unawaited(syncForLoggedInUser());
    });
  }

  static Future<void> syncForLoggedInUser() async {
    await init();
    final student = UserSession.studentId;
    if (!_ready || student == null || student.isEmpty) return;
    try {
      if (!await NotificationPreferences.isPushEnabled()) {
        await disableForLoggedOutOrDisabled();
        return;
      }
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        await disableForLoggedOutOrDisabled();
        return;
      }
      final token = await messaging.getToken();
      if (token == null || token.isEmpty || UserSession.studentId != student) {
        return;
      }
      if (token == _registeredToken && student == _registeredStudent) return;
      await _api.registerPushToken(token: token);
      if (UserSession.studentId != student) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('elecom.notifications.push_student', student);
      _registeredToken = token;
      _registeredStudent = student;
    } catch (_) {
      // Retry on the next login/resume; push setup must never fail a successful login.
      debugPrint('Push token registration failed; will retry on app resume.');
    }
  }

  static Future<void> disableForLoggedOutOrDisabled() async {
    await init();
    if (!_ready) return;
    try {
      final token =
          _registeredToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        try {
          await _api.unregisterPushToken(token: token);
        } finally {
          // Invalidate the device token even when the backend is temporarily unreachable.
          await FirebaseMessaging.instance.deleteToken();
        }
      }
    } catch (_) {
      // Logout remains available if FCM or the network is unavailable.
    } finally {
      _registeredToken = null;
      _registeredStudent = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('elecom.notifications.push_student');
    }
  }
}

class _PushLifecycle with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(PushNotificationService.syncForLoggedInUser());
    }
  }
}
