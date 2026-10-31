import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class SessionHttpClient extends http.BaseClient {
  SessionHttpClient({
    http.Client? inner,
    this.onUnauthorized,
    this.deviceName,
    Uri? apiOrigin,
  }) : _inner = inner ?? http.Client(),
       _apiOrigin = apiOrigin ?? Uri.parse(ApiConfig.baseUrl);

  final Uri _apiOrigin;

  final void Function()? onUnauthorized;
  final String? deviceName;
  static Future<String>? _deviceNameFuture;

  static Future<String> _readDeviceName() async {
    if (!Platform.isAndroid) return Platform.operatingSystem;
    try {
      final value = await const MethodChannel(
        'com.elecom.mobile/device_info',
      ).invokeMethod<String>('deviceName');
      return (value ?? 'Android')
          .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
          .trim();
    } catch (_) {
      return 'Android';
    }
  }

  static const Duration requestTimeout = Duration(seconds: 20);

  final http.Client _inner;
  final Map<String, String> _cookies = <String, String>{};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.origin != _apiOrigin.origin) {
      return _inner.send(request).timeout(requestTimeout);
    }
    request.headers.putIfAbsent(
      'User-Agent',
      () => 'ELECOM-Mobile (${Platform.operatingSystem})',
    );
    request.headers['X-ELECOM-Device'] =
        deviceName ?? await (_deviceNameFuture ??= _readDeviceName());
    final sentSession = _cookies['sessionid'];
    if (!const ['GET', 'HEAD', 'OPTIONS'].contains(request.method)) {
      final csrf = _cookies['csrftoken'];
      if (csrf != null && csrf.isNotEmpty) {
        request.headers['X-CSRFToken'] = csrf;
        request.headers.putIfAbsent('Referer', () => '${_apiOrigin.origin}/');
      }
    }
    final cookieHeader = _cookieHeader;
    if (cookieHeader.isNotEmpty) {
      request.headers['Cookie'] = cookieHeader;
    }

    final streamed = await _inner.send(request).timeout(requestTimeout);

    // A response from an old account must not clear a more recent login.
    final stillSameSession = _cookies['sessionid'] == sentSession;
    if (stillSameSession) {
      final setCookie = streamed.headers['set-cookie'];
      if (setCookie != null && setCookie.isNotEmpty) _storeSetCookie(setCookie);
      final authenticatedApi =
          request.url.path.startsWith('/api/mobile/') &&
          !request.url.path.startsWith('/api/mobile/auth/');
      if (streamed.statusCode == 401 &&
          authenticatedApi &&
          sentSession != null &&
          sentSession.isNotEmpty) {
        onUnauthorized?.call();
      }
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
      if (value.isEmpty) {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
  }

  void clearSession() {
    _cookies.clear();
  }

  Map<String, String> exportCookies() {
    return Map<String, String>.from(_cookies);
  }

  void importCookies(Map<String, String> cookies) {
    _cookies
      ..clear()
      ..addAll(cookies);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
