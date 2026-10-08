import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import 'mobile_api_paths.dart';

class ElecomMobileApi {
  ElecomMobileApi({http.Client? client})
    : _client = client ?? ApiClient.httpClient;

  final http.Client _client;
  static const int candidateRequirementMaxBytes = 8 * 1024 * 1024;

  /// Returned by [saveFaceEnrollment] when the server rejects enrollment because
  /// this face matches another user's enrollment (`ok: false`, JSON `code`).
  static const String codeFaceAlreadyEnrolled = 'face_already_enrolled';

  Future<Map<String, dynamic>> getElectionWindow() async {
    return _getJson(MobileApiPaths.electionWindow);
  }

  Future<Map<String, dynamic>> getAppUpdateInfo() async {
    return _getJson(MobileApiPaths.appUpdate);
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

  Future<Map<String, dynamic>> getEleVoteHistory() async {
    return _getJson(MobileApiPaths.elevoteChat);
  }

  Future<List<Map<String, dynamic>>> getCalendarEvents({
    int? year,
    int? month,
  }) async {
    String url = MobileApiPaths.calendarEvents;
    if (year != null && month != null) {
      url = '$url?year=$year&month=$month';
    }
    final res = await _getJson(url);
    final raw = res['events'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> getEleVoteHistorySince(int sinceId) async {
    return _getJson('${MobileApiPaths.elevoteChat}?since_id=$sinceId');
  }

  Future<Map<String, dynamic>> sendEleVoteMessage(String message) async {
    return _postJson(MobileApiPaths.elevoteChat, <String, dynamic>{
      'message': message,
    });
  }

  Future<Map<String, dynamic>> clearEleVoteHistory() async {
    return _deleteJson(MobileApiPaths.elevoteChat);
  }

  Future<Map<String, dynamic>> getTutorialState() async {
    return _getJson(MobileApiPaths.tutorialState);
  }

  Future<Map<String, dynamic>> updateTutorialState({
    bool? loginDone,
    bool? homeDone,
    bool? votingDone,
  }) async {
    final payload = <String, dynamic>{};
    if (loginDone != null) payload['login_done'] = loginDone;
    if (homeDone != null) payload['home_done'] = homeDone;
    if (votingDone != null) payload['voting_done'] = votingDone;
    return _postJson(MobileApiPaths.tutorialState, payload);
  }

  Future<Map<String, dynamic>> setProfilePhotoUrl({
    required String photoUrl,
  }) async {
    return _postJson(MobileApiPaths.accountProfilePhoto, <String, dynamic>{
      'photo_url': photoUrl,
    });
  }

  Future<Map<String, dynamic>> uploadProfilePhoto({
    required File imageFile,
  }) async {
    final uri = Uri.parse(MobileApiPaths.accountProfilePhoto);
    const fieldNames = ['photo', 'image', 'file', 'profile_photo'];

    ElecomApiException? lastErr;
    for (final field in fieldNames) {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      request.files.add(
        await http.MultipartFile.fromPath(field, imageFile.path),
      );

      http.StreamedResponse streamed;
      try {
        streamed = await _client.send(request);
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

    throw lastErr ??
        const ElecomApiException(
          'Request failed: could not upload profile photo',
        );
  }

  Future<Map<String, dynamic>> getBallot() async {
    return _getJson(MobileApiPaths.ballot);
  }

  Future<List<Map<String, dynamic>>> listAllCandidates() async {
    final uri = Uri.parse(MobileApiPaths.candidatesList);
    http.Response res;
    try {
      res = await _client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
    } catch (_) {
      throw const ElecomApiException('Network error: cannot reach server');
    }
    final decoded = _decode(res);
    final raw = decoded['candidates'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Returns ALL approved candidates for the current election regardless of
  /// the viewer's program/eligibility.  Used by the transparency Candidates
  /// screen only – the ballot remains eligibility-gated on a separate endpoint.
  ///
  /// Falls back to [candidatesList] (the same endpoint the home dashboard uses)
  /// if [candidatesAll] returns a 404, so the screen works even when the
  /// dedicated all-candidates route has not been added to the backend yet.
  Future<List<Map<String, dynamic>>> listAllCandidatesTransparency() async {
    // Try the dedicated /candidates/all/ endpoint first.
    final allUri = Uri.parse(MobileApiPaths.candidatesAll);
    http.Response res;
    try {
      res = await _client.get(
        allUri,
        headers: const {'Accept': 'application/json'},
      );
    } catch (_) {
      throw const ElecomApiException('Network error: cannot reach server');
    }

    // If the dedicated endpoint is missing (404) fall back to the standard
    // candidates list that the home dashboard already uses successfully.
    if (res.statusCode == 404) {
      return listAllCandidates();
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ElecomApiException(
        'Server error (${res.statusCode}): Invalid JSON response from candidates/all/',
      );
    }

    if (res.statusCode >= 400 && decoded['ok'] != true) {
      final msg =
          (decoded['error'] ??
                  decoded['message'] ??
                  decoded['detail'] ??
                  'Request failed')
              .toString();
      throw ElecomApiException('Request failed (${res.statusCode}): $msg');
    }

    final raw = decoded['candidates'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchCandidates(String query) async {
    final q = query.trim();
    if (q.isEmpty) return <Map<String, dynamic>>[];
    final uri = Uri.parse(
      MobileApiPaths.candidatesSearch,
    ).replace(queryParameters: {'q': q});
    http.Response res;
    try {
      res = await _client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
    } catch (_) {
      throw const ElecomApiException('Network error: cannot reach server');
    }
    final decoded = _decode(res);
    final raw = decoded['candidates'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> submitCandidateApplication({
    required Map<String, String> fields,
    required File candidatePhoto,
    required Uint8List certificatePdf,
    File? partyLogo,
  }) async {
    final uri = Uri.parse(MobileApiPaths.candidateApplicationSubmit);
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..fields.addAll(fields)
      ..files.add(
        await http.MultipartFile.fromPath(
          'candidate_photo',
          candidatePhoto.path,
        ),
      );

    if (certificatePdf.isEmpty ||
        certificatePdf.length > candidateRequirementMaxBytes) {
      throw const ElecomApiException(
        'Certificate must be no larger than 8 MB.',
      );
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'certificate_pdf',
        certificatePdf,
        filename: 'certificate_of_candidacy.pdf',
      ),
    );

    if (partyLogo != null) {
      request.files.add(
        await http.MultipartFile.fromPath('party_logo', partyLogo.path),
      );
    }

    http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request);
    } catch (e, stackTrace) {
      developer.log(
        'Candidate application submit failed to reach $uri',
        name: 'ElecomMobileApi',
        error: e,
        stackTrace: stackTrace,
      );
      throw const ElecomApiException('Network error: cannot reach server');
    }
    return _decodeStreamed(streamed);
  }

  Future<Map<String, dynamic>> getCandidateApplicationStatus() async {
    return _getJson(MobileApiPaths.candidateApplicationStatus);
  }

  Future<Uint8List> getCandidateCertificate(String applicationId) async {
    final response = await _client.get(
      Uri.parse(MobileApiPaths.candidateCertificate(applicationId)),
      headers: {'Accept': 'application/pdf'},
    );
    if (response.statusCode != 200 ||
        !response.headers['content-type'].toString().startsWith(
          'application/pdf',
        ) ||
        String.fromCharCodes(response.bodyBytes.take(5)) != '%PDF-') {
      throw const ElecomApiException(
        'Could not load your saved certificate. Please try again.',
      );
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> archiveCandidateCertificate(
    String applicationId,
    Uint8List pdf,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(MobileApiPaths.candidateCertificate(applicationId)),
    )..headers['Accept'] = 'application/json';
    request.files.add(
      http.MultipartFile.fromBytes(
        'certificate_pdf',
        pdf,
        filename: 'certificate_of_candidacy.pdf',
      ),
    );
    return _decodeStreamed(await _client.send(request));
  }

  Future<Map<String, dynamic>> submitCandidateRequirements({
    required Map<String, File> files,
  }) async {
    if (files.isEmpty) {
      throw const ElecomApiException('Please attach your requirements.');
    }
    final uri = Uri.parse(MobileApiPaths.candidateApplicationRequirements);
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json';
    for (final entry in files.entries) {
      final size = await entry.value.length();
      if (size == 0 || size > candidateRequirementMaxBytes) {
        final name = entry.value.uri.pathSegments.last;
        throw ElecomApiException(
          '$name must be a non-empty file no larger than 8 MB.',
          code: 'invalid_requirement_size',
        );
      }
      request.files.add(
        await http.MultipartFile.fromPath(entry.key, entry.value.path),
      );
    }
    http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request);
    } catch (e, stackTrace) {
      developer.log(
        'Candidate requirements upload failed to reach $uri',
        name: 'ElecomMobileApi',
        error: e,
        stackTrace: stackTrace,
      );
      throw const ElecomApiException('Network error: cannot reach server');
    }
    return _decodeStreamed(streamed);
  }

  Future<List<String>> getCandidateApplicationParties() async {
    final decoded = await _getJson(MobileApiPaths.candidateApplicationParties);
    final raw = decoded['parties'];
    if (raw is! List) return <String>[];
    final names = raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  Future<Map<String, dynamic>> getVoteStatus() async {
    return _getJson(MobileApiPaths.voteStatus);
  }

  Future<Map<String, dynamic>> getResults() async {
    return _getJson(MobileApiPaths.results);
  }

  Future<Map<String, dynamic>> getResultsAnalytics() async {
    return _getJson(MobileApiPaths.resultsAnalytics);
  }

  Future<Map<String, dynamic>> getVoteReceipt() async {
    return _getJson(MobileApiPaths.voteReceipt);
  }

  Future<Map<String, dynamic>> submitVote(Map<String, dynamic> payload) async {
    return _postJson(MobileApiPaths.voteSubmit, payload);
  }

  Future<Map<String, dynamic>> getVoteLedger() async {
    return _getJson(MobileApiPaths.voteLedger);
  }

  Future<Map<String, dynamic>> checkNetworkAccess({String? deviceIp}) async {
    final payload = <String, dynamic>{};
    final ip = (deviceIp ?? '').trim();
    if (ip.isNotEmpty) {
      payload['device_ip'] = ip;
      payload['local_ip'] = ip;
    }
    return _postJson(MobileApiPaths.networkCheck, payload);
  }

  Future<Map<String, dynamic>> getCloudinarySignature() async {
    // Use non-admin signature for student profile photo uploads.
    return _getJson(MobileApiPaths.cloudinaryProfileSignature);
  }

  Future<Map<String, dynamic>> getFaceCloudinarySignature() async {
    return _getJson(MobileApiPaths.cloudinaryFaceEnrollmentSignature);
  }

  Future<Map<String, dynamic>> getFaceEnrollmentStatus() async {
    return _getJson(MobileApiPaths.faceEnrollmentStatus);
  }

  /// Persists enrollment via backend (Face++, Cloudinary, DB). Sends image bytes only —
  /// no Face++ credentials on device.
  Future<Map<String, dynamic>> saveFaceEnrollment({
    required File capturedImageFile,
  }) async {
    final uri = Uri.parse(MobileApiPaths.faceEnrollmentSave);
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..files.add(
        await http.MultipartFile.fromPath('face_image', capturedImageFile.path),
      );
    http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request);
    } catch (_) {
      throw const ElecomApiException('Network error: cannot reach server');
    }
    return _decodeStreamed(streamed);
  }

  /// Face verification for voting: image sent to backend; Face++ Compare runs server-side only.
  Future<Map<String, dynamic>> verifyFaceForVote({
    required File liveFaceImageFile,
    required bool livenessPassed,
    int? electionId,
  }) async {
    final uri = Uri.parse(MobileApiPaths.faceVerificationVerify);
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..fields['liveness_passed'] = livenessPassed ? 'true' : 'false'
      ..files.add(
        await http.MultipartFile.fromPath('face_image', liveFaceImageFile.path),
      );
    if (electionId != null) {
      request.fields['election_id'] = '$electionId';
    }
    http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request);
    } catch (_) {
      throw const ElecomApiException('Network error: cannot reach server');
    }
    return _decodeStreamed(streamed);
  }

  Future<Map<String, dynamic>> updateProfilePhotoUrl({
    required String photoUrl,
  }) async {
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
    final uploaded = await uploadImageToCloudinaryDetailed(
      imageFile: imageFile,
      signatureType: CloudinarySignatureType.profilePhoto,
    );
    return (uploaded['secure_url'] ?? '').toString();
  }

  Future<Map<String, dynamic>> uploadImageToCloudinaryDetailed({
    required File imageFile,
    CloudinarySignatureType signatureType =
        CloudinarySignatureType.profilePhoto,
  }) async {
    final sigRes = signatureType == CloudinarySignatureType.faceEnrollment
        ? await getFaceCloudinarySignature()
        : await getCloudinarySignature();

    Map<String, dynamic> sig = sigRes;
    if (sigRes['data'] is Map<String, dynamic>) {
      sig = sigRes['data'] as Map<String, dynamic>;
    }

    final cloudName =
        (sig['cloud_name'] ?? sig['cloudName'] ?? sig['cloud'] ?? '')
            .toString()
            .trim();
    final apiKey = (sig['api_key'] ?? sig['apiKey'] ?? sig['key'] ?? '')
        .toString()
        .trim();
    final timestamp = (sig['timestamp'] ?? '').toString().trim();
    final signature = (sig['signature'] ?? '').toString().trim();

    if (cloudName.isEmpty ||
        apiKey.isEmpty ||
        timestamp.isEmpty ||
        signature.isEmpty) {
      throw const ElecomApiException(
        'Cloudinary signature response missing required fields',
      );
    }

    final folder = (sig['folder'] ?? '').toString().trim();
    final publicId = (sig['public_id'] ?? sig['publicId'] ?? '')
        .toString()
        .trim();

    final uploadUri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', uploadUri);

    request.fields['api_key'] = apiKey;
    request.fields['timestamp'] = timestamp;
    request.fields['signature'] = signature;
    if (folder.isNotEmpty) request.fields['folder'] = folder;
    if (publicId.isNotEmpty) request.fields['public_id'] = publicId;

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    http.StreamedResponse streamed;
    try {
      streamed = await http.Client().send(request);
    } catch (_) {
      throw const ElecomApiException('Network error: cannot reach Cloudinary');
    }

    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw ElecomApiException(
        'Cloudinary upload failed (${streamed.statusCode}): $body',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const ElecomApiException('Cloudinary upload failed: invalid JSON');
    }

    final secureUrl = (decoded['secure_url'] ?? decoded['url'] ?? '')
        .toString()
        .trim();
    if (secureUrl.isEmpty) {
      throw const ElecomApiException(
        'Cloudinary upload failed: missing secure_url',
      );
    }

    return <String, dynamic>{
      'secure_url': secureUrl,
      'public_id': (decoded['public_id'] ?? '').toString().trim(),
      'raw': decoded,
    };
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final res = await _getJson(MobileApiPaths.notifications);
    final raw = res['notifications'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> createNotification({
    required String title,
    required String body,
    String type = 'general',
    int? receiptId,
    bool pinned = false,
  }) async {
    final res = await _postJson(
      MobileApiPaths.notificationsCreate,
      <String, dynamic>{
        'title': title,
        'body': body,
        'type': type,
        'receipt_id': receiptId,
        'pinned': pinned,
      },
    );
    final raw = res['notification'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  Future<void> markNotificationRead(int id) async {
    await _postJson(MobileApiPaths.notificationsRead, <String, dynamic>{
      'id': id,
    });
  }

  Future<void> markNotificationUnread(int id) async {
    await _postJson(MobileApiPaths.notificationsUnread, <String, dynamic>{
      'id': id,
    });
  }

  Future<void> setNotificationPinned({
    required int id,
    required bool pinned,
  }) async {
    await _postJson(MobileApiPaths.notificationsPin, <String, dynamic>{
      'id': id,
      'pinned': pinned,
    });
  }

  Future<void> deleteNotification(int id) async {
    await _postJson(MobileApiPaths.notificationsDelete, <String, dynamic>{
      'id': id,
    });
  }

  Future<void> markAllNotificationsRead() async {
    await _postJson(MobileApiPaths.notificationsReadAll, <String, dynamic>{});
  }

  Future<void> registerPushToken({required String token}) async {
    await _postJson(MobileApiPaths.pushTokenRegister, <String, dynamic>{
      'token': token,
      'platform': Platform.operatingSystem,
    });
  }

  Future<void> unregisterPushToken({required String token}) async {
    await _postJson(MobileApiPaths.pushTokenUnregister, <String, dynamic>{
      'token': token,
      'platform': Platform.operatingSystem,
    });
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final uri = Uri.parse(url);
    http.Response res;
    try {
      res = await _client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
    } catch (_) {
      throw const ElecomApiException('Network error: cannot reach server');
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse(url);
    http.Response res;
    try {
      res = await _client.post(
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

  Future<Map<String, dynamic>> _deleteJson(String url) async {
    final uri = Uri.parse(url);
    http.Response res;
    try {
      res = await _client.delete(
        uri,
        headers: const {'Accept': 'application/json'},
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
        final msg = (decoded['error'] ?? decoded['message'] ?? 'Request failed')
            .toString();
        throw ElecomApiException(
          'Request failed (${res.statusCode}): $msg',
          code: _parseApiErrorCode(decoded),
        );
      }
      throw ElecomApiException(
        'Server error (${res.statusCode}): Invalid JSON',
      );
    } catch (e) {
      if (e is ElecomApiException) rethrow;
      throw ElecomApiException(
        'Server error (${res.statusCode}): Invalid JSON',
      );
    }
  }

  Future<Map<String, dynamic>> _decodeStreamed(
    http.StreamedResponse streamed,
  ) async {
    if (streamed.statusCode == 413) {
      await streamed.stream.drain<void>();
      throw const ElecomApiException(
        'The server rejected the upload size. Please try smaller files or contact ELECOM support.',
        code: 'upload_too_large',
      );
    }
    try {
      final body = await streamed.stream.bytesToString();
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['ok'] == true) return decoded;
        final msg = (decoded['error'] ?? decoded['message'] ?? 'Request failed')
            .toString();
        throw ElecomApiException(
          'Request failed (${streamed.statusCode}): $msg',
          code: _parseApiErrorCode(decoded),
        );
      }
      throw ElecomApiException(
        'Server error (${streamed.statusCode}): Invalid JSON',
      );
    } catch (e) {
      if (e is ElecomApiException) rethrow;
      throw ElecomApiException(
        'Server error (${streamed.statusCode}): Invalid JSON',
      );
    }
  }

  static String? _parseApiErrorCode(Map<String, dynamic> decoded) {
    final direct = (decoded['code'] ?? decoded['error_code'] ?? '')
        .toString()
        .trim();
    if (direct.isNotEmpty) return direct;
    final detail = decoded['detail'];
    if (detail is Map<String, dynamic>) {
      final c = (detail['code'] ?? '').toString().trim();
      if (c.isNotEmpty) return c;
    }
    return null;
  }

  /// Server-indicated duplicate face (supports alternate codes some backends use).
  static bool isFaceAlreadyEnrolled(ElecomApiException e) {
    final c = (e.code ?? '').trim().toLowerCase();
    return c == codeFaceAlreadyEnrolled ||
        c == 'duplicate_face' ||
        c == 'face_duplicate';
  }
}

class ElecomApiException implements Exception {
  const ElecomApiException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'ElecomApiException(message: $message, code: $code)';
}

enum CloudinarySignatureType { profilePhoto, faceEnrollment }
