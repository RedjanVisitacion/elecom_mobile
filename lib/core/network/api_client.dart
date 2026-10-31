import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'session_http_client.dart';

class ApiClient {
  ApiClient._();

  static final ValueNotifier<int> sessionEnded = ValueNotifier<int>(0);
  static String sessionEndMessage =
      'Your session has ended. Please sign in again.';

  static void endSession({String? message}) {
    sessionEndMessage =
        message ?? 'Your session has ended. Please sign in again.';
    sessionEnded.value++;
  }

  static final SessionHttpClient _client = SessionHttpClient(
    inner: http.Client(),
    onUnauthorized: endSession,
  );

  static http.Client get httpClient => _client;

  static void clearSession() => _client.clearSession();

  static Map<String, String> exportCookies() => _client.exportCookies();

  static void importCookies(Map<String, String> cookies) =>
      _client.importCookies(cookies);
}
