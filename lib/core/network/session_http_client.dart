import 'dart:async';

import 'package:http/http.dart' as http;

class SessionHttpClient extends http.BaseClient {
  SessionHttpClient({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;
  final Map<String, String> _cookies = <String, String>{};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final cookieHeader = _cookieHeader;
    if (cookieHeader.isNotEmpty) {
      request.headers['Cookie'] = cookieHeader;
    }

    final streamed = await _inner.send(request);

    final setCookie = streamed.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      _storeSetCookie(setCookie);
    }

    return streamed;
  }

  String get _cookieHeader {
    if (_cookies.isEmpty) return '';
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  void _storeSetCookie(String headerValue) {
    final parts = headerValue.split(',');
    for (final part in parts) {
      final cookiePair = part.split(';').first.trim();
      final eq = cookiePair.indexOf('=');
      if (eq <= 0) continue;
      final name = cookiePair.substring(0, eq).trim();
      final value = cookiePair.substring(eq + 1).trim();
      if (name.isEmpty) continue;
      _cookies[name] = value;
    }
  }

  void clearSession() {
    _cookies.clear();
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
