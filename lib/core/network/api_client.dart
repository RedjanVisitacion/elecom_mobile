import 'package:http/http.dart' as http;

import 'session_http_client.dart';

class ApiClient {
  ApiClient._();

  static final SessionHttpClient _client = SessionHttpClient(inner: http.Client());

  static http.Client get httpClient => _client;

  static void clearSession() => _client.clearSession();
}
