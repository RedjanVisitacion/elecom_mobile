import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import 'mobile_api_paths.dart';

class ElecomMobileApi {
  Future<Map<String, dynamic>> getElectionWindow() async {
    return _getJson(MobileApiPaths.electionWindow);
  }

  Future<Map<String, dynamic>> getProfile() async {
    return _getJson(MobileApiPaths.accountProfile);
  }

  Future<Map<String, dynamic>> getBallot() async {
    return _getJson(MobileApiPaths.ballot);
  }

  Future<Map<String, dynamic>> getVoteStatus() async {
    return _getJson(MobileApiPaths.voteStatus);
  }

  Future<Map<String, dynamic>> getVoteReceipt() async {
    return _getJson(MobileApiPaths.voteReceipt);
  }

  Future<Map<String, dynamic>> submitVote(Map<String, dynamic> payload) async {
    return _postJson(MobileApiPaths.voteSubmit, payload);
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final uri = Uri.parse(url);
    http.Response res;
    try {
      res = await ApiClient.httpClient.get(uri, headers: const {'Accept': 'application/json'});
    } catch (_) {
      throw const ElecomApiException('Network error: cannot reach server');
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _postJson(String url, Map<String, dynamic> payload) async {
    final uri = Uri.parse(url);
    http.Response res;
    try {
      res = await ApiClient.httpClient.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );
    } catch (_) {
      throw const ElecomApiException('Network error: cannot reach server');
    }
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['ok'] == true) return decoded;
        final msg = (decoded['error'] ?? decoded['message'] ?? 'Request failed').toString();
        throw ElecomApiException('Request failed (${res.statusCode}): $msg');
      }
      throw ElecomApiException('Server error (${res.statusCode}): Invalid JSON');
    } catch (e) {
      if (e is ElecomApiException) rethrow;
      throw ElecomApiException('Server error (${res.statusCode}): Invalid JSON');
    }
  }
}

class ElecomApiException implements Exception {
  const ElecomApiException(this.message);

  final String message;

  @override
  String toString() => 'ElecomApiException(message: $message)';
}
