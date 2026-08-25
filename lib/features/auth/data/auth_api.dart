import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';

class AuthApi {
  Future<LoginResponse> login({required String studentId, required String password}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/login/');

    http.Response res;
    try {
      res = await ApiClient.httpClient.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'studentId': studentId,
          'password': password,
        }),
      );
    } catch (_) {
      throw const AuthException('Network error: cannot reach server');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AuthException(
        'The server returned an unexpected response. Please try again.',
      );
    }

    final ok = body['ok'] == true;
    if (ok) {
      final user = body['user'] is Map<String, dynamic> ? (body['user'] as Map<String, dynamic>) : const <String, dynamic>{};

      final resolvedStudentId = (body['student_id'] ?? body['studentId'] ?? user['student_id'] ?? user['studentId'] ?? '').toString();
      final resolvedRole = (body['role'] ?? user['role'] ?? '').toString();
      final resolvedFullName = (body['full_name'] ?? body['fullName'] ?? body['name'] ?? body['username'] ?? user['full_name'] ?? user['fullName'] ?? user['name'] ?? user['username'] ?? '')
          .toString();

      return LoginResponse(
        ok: true,
        studentId: resolvedStudentId,
        role: resolvedRole,
        fullName: resolvedFullName,
      );
    }

    final error = (body['error'] ?? 'Login failed').toString();
    final friendlyMessage = _friendlyLoginError(res.statusCode, error);
    throw AuthException(friendlyMessage, statusCode: res.statusCode);
  }

  /// Returns a clean, user-friendly error message without exposing HTTP codes.
  static String _friendlyLoginError(int statusCode, String serverMessage) {
    // Strip any existing "Login failed (XXX):" prefix the server might return.
    final clean = serverMessage
        .replaceFirst(RegExp(r'^Login failed \(\d+\):\s*'), '')
        .trim();

    switch (statusCode) {
      case 401:
      case 403:
        // Wrong credentials or account not authorised.
        if (clean.toLowerCase().contains('not found') ||
            clean.toLowerCase().contains('no account') ||
            clean.toLowerCase().contains('does not exist')) {
          return 'No account found with that Student ID.';
        }
        if (clean.toLowerCase().contains('password') ||
            clean.toLowerCase().contains('credentials') ||
            clean.toLowerCase().contains('invalid')) {
          return 'Incorrect Student ID or password. Please try again.';
        }
        if (clean.toLowerCase().contains('deactivated') ||
            clean.toLowerCase().contains('disabled') ||
            clean.toLowerCase().contains('suspended')) {
          return 'Your account has been deactivated. Contact ELECOM.';
        }
        return 'Incorrect Student ID or password. Please try again.';
      case 404:
        return 'No account found with that Student ID.';
      case 429:
        return 'Too many login attempts. Please wait a moment and try again.';
      case 500:
      case 502:
      case 503:
        return 'The server is temporarily unavailable. Please try again shortly.';
      default:
        // Use server message if it looks human-readable, otherwise generic.
        if (clean.isNotEmpty &&
            !clean.toLowerCase().startsWith('request failed') &&
            !clean.toLowerCase().startsWith('server error')) {
          return clean;
        }
        return 'Unable to sign in. Please check your connection and try again.';
    }
  }
}

class LoginResponse {
  const LoginResponse({
    required this.ok,
    required this.studentId,
    required this.role,
    required this.fullName,
  });

  final bool ok;
  final String studentId;
  final String role;
  final String fullName;
}

class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AuthException(statusCode: $statusCode, message: $message)';
}
