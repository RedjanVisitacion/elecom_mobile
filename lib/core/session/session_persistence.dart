import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/notification_center_store.dart';
import '../notifications/push_notification_service.dart';
import '../network/api_client.dart';
import 'user_session.dart';

class SessionPersistence {
  SessionPersistence._();

  static const _kCookies = 'elecom.session.cookies';
  static const _kUser = 'elecom.session.user';

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    final cookies = ApiClient.exportCookies();
    await prefs.setString(_kCookies, jsonEncode(cookies));

    final user = <String, dynamic>{
      'studentId': UserSession.studentId,
      'fullName': UserSession.fullName,
      'firstName': UserSession.firstName,
      'middleName': UserSession.middleName,
      'lastName': UserSession.lastName,
      'profilePhotoUrl': UserSession.profilePhotoUrl,
      'role': UserSession.role,
      'department': UserSession.department,
      'position': UserSession.position,
      'yearSection': UserSession.yearSection,
    };
    await prefs.setString(_kUser, jsonEncode(user));
  }

  static Future<bool> restore() async {
    final prefs = await SharedPreferences.getInstance();

    final cookiesJson = prefs.getString(_kCookies);
    if (cookiesJson == null || cookiesJson.trim().isEmpty) return false;

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(cookiesJson) as Map<String, dynamic>;
    } catch (_) {
      return false;
    }

    final cookies = decoded.map((k, v) => MapEntry(k, (v ?? '').toString()));
    if ((cookies['sessionid'] ?? '').isEmpty) return false;

    ApiClient.importCookies(cookies);

    final userJson = prefs.getString(_kUser);
    if (userJson != null && userJson.trim().isNotEmpty) {
      try {
        final user = jsonDecode(userJson) as Map<String, dynamic>;
        UserSession.setFromResponse(user);
      } catch (_) {
        // ignore
      }
    }

    return true;
  }

  static Future<void> clear() async {
    // Remove in-memory access before any optional network cleanup.
    ApiClient.clearSession();
    NotificationCenterStore.clearLocal();
    UserSession.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCookies);
      await prefs.remove(_kUser);
    } catch (_) {
      // The server has revoked this session; local access is already cleared.
    }
    try {
      await PushNotificationService.disableForLoggedOutOrDisabled();
    } catch (_) {
      // A push-service failure must not keep an account signed in.
    }
  }
}
