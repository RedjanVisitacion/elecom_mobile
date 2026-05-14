import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';

/// Stateless API layer for the forgot-password / OTP / reset flow.
///
/// All three endpoints are unauthenticated (no session cookie required).
/// [requestOtp] returns 404 when no account matches the identifier.
class ForgotPasswordApi {
  // ── Endpoint paths ────────────────────────────────────────────────────────
  static String get _base => '${ApiConfig.baseUrl}/api/mobile/auth';
  static String get _forgotUrl => '$_base/forgot-password/';
  static String get _verifyUrl => '$_base/verify-otp/';
  static String get _resetUrl => '$_base/reset-password/';

  // ── Request helpers ───────────────────────────────────────────────────────
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ForgotPasswordException(
        'Server error (${res.statusCode}): unexpected response.',
        statusCode: res.statusCode,
      );
    }
  }

  static void _assertOk(Map<String, dynamic> body, int statusCode) {
    if (body['ok'] != true) {
      final msg = (body['error'] ?? body['detail'] ?? 'Something went wrong.')
          .toString();
      throw ForgotPasswordException(msg, statusCode: statusCode);
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Step 1 — request an OTP.
  ///
  /// [identifier] is either a Student ID or a registered email address.
  /// Throws [ForgotPasswordException] if no account exists (or email is missing on file).
  /// On success, returns the masked email for display (e.g. "r***@gmail.com").
  Future<ForgotPasswordResponse> requestOtp({
    required String identifier,
  }) async {
    http.Response res;
    try {
      res = await ApiClient.httpClient.post(
        Uri.parse(_forgotUrl),
        headers: _headers,
        body: jsonEncode({'identifier': identifier.trim()}),
      );
    } catch (_) {
      throw const ForgotPasswordException(
          'Network error: cannot reach server.');
    }
    final body = _decode(res);
    _assertOk(body, res.statusCode);
    return ForgotPasswordResponse(
      maskedEmail: (body['masked_email'] ?? '').toString(),
    );
  }

  /// Step 2 — verify the 6-digit OTP.
  ///
  /// Returns a short-lived [resetToken] that must be passed to [resetPassword].
  Future<VerifyOtpResponse> verifyOtp({
    required String identifier,
    required String otp,
  }) async {
    http.Response res;
    try {
      res = await ApiClient.httpClient.post(
        Uri.parse(_verifyUrl),
        headers: _headers,
        body: jsonEncode({
          'identifier': identifier.trim(),
          'otp': otp.trim(),
        }),
      );
    } catch (_) {
      throw const ForgotPasswordException(
          'Network error: cannot reach server.');
    }
    final body = _decode(res);
    _assertOk(body, res.statusCode);
    return VerifyOtpResponse(
      resetToken: (body['reset_token'] ?? '').toString(),
    );
  }

  /// Step 3 — set a new password using the [resetToken] from step 2.
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    http.Response res;
    try {
      res = await ApiClient.httpClient.post(
        Uri.parse(_resetUrl),
        headers: _headers,
        body: jsonEncode({
          'reset_token': resetToken,
          'new_password': newPassword,
        }),
      );
    } catch (_) {
      throw const ForgotPasswordException(
          'Network error: cannot reach server.');
    }
    final body = _decode(res);
    _assertOk(body, res.statusCode);
  }
}

// ── Response models ───────────────────────────────────────────────────────────

class ForgotPasswordResponse {
  const ForgotPasswordResponse({required this.maskedEmail});
  final String maskedEmail;
}

class VerifyOtpResponse {
  const VerifyOtpResponse({required this.resetToken});
  final String resetToken;
}

// ── Exception ─────────────────────────────────────────────────────────────────

class ForgotPasswordException implements Exception {
  const ForgotPasswordException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'ForgotPasswordException(statusCode: $statusCode, message: $message)';
}
