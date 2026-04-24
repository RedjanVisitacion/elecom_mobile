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
      throw AuthException(
        'Server error (${res.statusCode}): ${res.body.isEmpty ? 'Empty response' : 'Invalid JSON'}',
        statusCode: res.statusCode,
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
    throw AuthException('Login failed (${res.statusCode}): $error', statusCode: res.statusCode);
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
