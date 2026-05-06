import 'dart:io' show Platform;

class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (Platform.isAndroid) return 'http://192.168.101.7:8000';
    return 'http://127.0.0.1:8000';
  }
}
