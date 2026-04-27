import 'dart:convert';
import 'dart:io';

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

  Future<Map<String, dynamic>> submitAppRating({
    required int rating,
    required String label,
  }) async {
    return _postJson(MobileApiPaths.accountAppRating, <String, dynamic>{
      'rating': rating,
      'label': label,
    });
  }

  Future<Map<String, dynamic>> setProfilePhotoUrl({required String photoUrl}) async {
    return _postJson(MobileApiPaths.accountProfilePhoto, <String, dynamic>{
      'photo_url': photoUrl,
    });
  }

  Future<Map<String, dynamic>> uploadProfilePhoto({required File imageFile}) async {
    final uri = Uri.parse(MobileApiPaths.accountProfilePhoto);
    const fieldNames = ['photo', 'image', 'file', 'profile_photo'];

    ElecomApiException? lastErr;
    for (final field in fieldNames) {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      request.files.add(await http.MultipartFile.fromPath(field, imageFile.path));

      http.StreamedResponse streamed;
      try {
        streamed = await ApiClient.httpClient.send(request);
      } catch (_) {
        throw const ElecomApiException('Network error: cannot reach server');
      }

      try {
        return await _decodeStreamed(streamed);
      } catch (e) {
        if (e is ElecomApiException) {
          lastErr = e;
          continue;
        }
        rethrow;
      }
    }

    throw lastErr ?? const ElecomApiException('Request failed: could not upload profile photo');
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

  Future<Map<String, dynamic>> getCloudinarySignature() async {
    // Use non-admin signature for student profile photo uploads.
    return _getJson(MobileApiPaths.cloudinaryProfileSignature);
  }

  Future<Map<String, dynamic>> updateProfilePhotoUrl({required String photoUrl}) async {
    return _postJson(MobileApiPaths.accountProfileUpdate, <String, dynamic>{
      'photo_url': photoUrl,
      'photoUrl': photoUrl,
      'photo': photoUrl,
      'avatar': photoUrl,
      'profile_photo_url': photoUrl,
      'profilePhotoUrl': photoUrl,
      'user': <String, dynamic>{
        'photo_url': photoUrl,
        'photoUrl': photoUrl,
        'photo': photoUrl,
        'avatar': photoUrl,
        'profile_photo_url': photoUrl,
        'profilePhotoUrl': photoUrl,
      },
    });
  }

  Future<Map<String, dynamic>> updateProfileDetails({
    required String email,
    required String phone,
  }) async {
    return _postJson(MobileApiPaths.accountProfileUpdate, <String, dynamic>{
      'email': email,
      'phone': phone,
      'phone_number': phone,
      'contact_no': phone,
      'contactNo': phone,
      'user': <String, dynamic>{
        'email': email,
        'phone': phone,
        'phone_number': phone,
        'contact_no': phone,
        'contactNo': phone,
      },
      'student': <String, dynamic>{
        'email': email,
        'phone': phone,
        'phone_number': phone,
        'contact_no': phone,
        'contactNo': phone,
      },
    });
  }

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    return _postJson(MobileApiPaths.accountProfilePassword, <String, dynamic>{
      'old_password': oldPassword,
      'new_password': newPassword,
      'confirm_password': confirmPassword,
      'oldPassword': oldPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });
  }

  Future<String> uploadImageToCloudinary({required File imageFile}) async {
    final sigRes = await getCloudinarySignature();

    Map<String, dynamic> sig = sigRes;
    if (sigRes['data'] is Map<String, dynamic>) {
      sig = sigRes['data'] as Map<String, dynamic>;
    }

    final cloudName = (sig['cloud_name'] ?? sig['cloudName'] ?? sig['cloud'] ?? '').toString().trim();
    final apiKey = (sig['api_key'] ?? sig['apiKey'] ?? sig['key'] ?? '').toString().trim();
    final timestamp = (sig['timestamp'] ?? '').toString().trim();
    final signature = (sig['signature'] ?? '').toString().trim();

    if (cloudName.isEmpty || apiKey.isEmpty || timestamp.isEmpty || signature.isEmpty) {
      throw const ElecomApiException('Cloudinary signature response missing required fields');
    }

    final folder = (sig['folder'] ?? '').toString().trim();
    final publicId = (sig['public_id'] ?? sig['publicId'] ?? '').toString().trim();

    final uploadUri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uploadUri);

    request.fields['api_key'] = apiKey;
    request.fields['timestamp'] = timestamp;
    request.fields['signature'] = signature;
    if (folder.isNotEmpty) request.fields['folder'] = folder;
    if (publicId.isNotEmpty) request.fields['public_id'] = publicId;

    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    http.StreamedResponse streamed;
    try {
      streamed = await http.Client().send(request);
    } catch (_) {
      throw const ElecomApiException('Network error: cannot reach Cloudinary');
    }

    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw ElecomApiException('Cloudinary upload failed (${streamed.statusCode}): $body');
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const ElecomApiException('Cloudinary upload failed: invalid JSON');
    }

    final secureUrl = (decoded['secure_url'] ?? decoded['url'] ?? '').toString().trim();
    if (secureUrl.isEmpty) {
      throw const ElecomApiException('Cloudinary upload failed: missing secure_url');
    }

    return secureUrl;
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final res = await _getJson(MobileApiPaths.notifications);
    final raw = res['notifications'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> createNotification({
    required String title,
    required String body,
    String type = 'general',
    int? receiptId,
    bool pinned = false,
  }) async {
    final res = await _postJson(MobileApiPaths.notificationsCreate, <String, dynamic>{
      'title': title,
      'body': body,
      'type': type,
      'receipt_id': receiptId,
      'pinned': pinned,
    });
    final raw = res['notification'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  Future<void> markNotificationRead(int id) async {
    await _postJson(MobileApiPaths.notificationsRead, <String, dynamic>{'id': id});
  }

  Future<void> markNotificationUnread(int id) async {
    await _postJson(MobileApiPaths.notificationsUnread, <String, dynamic>{'id': id});
  }

  Future<void> setNotificationPinned({required int id, required bool pinned}) async {
    await _postJson(MobileApiPaths.notificationsPin, <String, dynamic>{
      'id': id,
      'pinned': pinned,
    });
  }

  Future<void> deleteNotification(int id) async {
    await _postJson(MobileApiPaths.notificationsDelete, <String, dynamic>{'id': id});
  }

  Future<void> markAllNotificationsRead() async {
    await _postJson(MobileApiPaths.notificationsReadAll, <String, dynamic>{});
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

  Future<Map<String, dynamic>> _decodeStreamed(http.StreamedResponse streamed) async {
    try {
      final body = await streamed.stream.bytesToString();
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['ok'] == true) return decoded;
        final msg = (decoded['error'] ?? decoded['message'] ?? 'Request failed').toString();
        throw ElecomApiException('Request failed (${streamed.statusCode}): $msg');
      }
      throw ElecomApiException('Server error (${streamed.statusCode}): Invalid JSON');
    } catch (e) {
      if (e is ElecomApiException) rethrow;
      throw ElecomApiException('Server error (${streamed.statusCode}): Invalid JSON');
    }
  }
}

class ElecomApiException implements Exception {
  const ElecomApiException(this.message);

  final String message;

  @override
  String toString() => 'ElecomApiException(message: $message)';
}
