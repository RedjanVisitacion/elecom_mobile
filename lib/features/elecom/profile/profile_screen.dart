import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/config/api_config.dart';
import '../../../core/session/user_session.dart';
import '../data/elecom_mobile_api.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ElecomMobileApi _api = ElecomMobileApi();
  final ImagePicker _picker = ImagePicker();

  bool _loading = false;
  Map<String, dynamic>? _profile;
  int _photoCacheBuster = 0;

  @override
  void initState() {
    super.initState();
    _hydrateFromSession();
    _refreshProfile();
  }

  void _hydrateFromSession() {
    setState(() {
      _profile = {
        'full_name': UserSession.fullName,
        'student_id': UserSession.studentId,
        'role': UserSession.role,
        'department': UserSession.department,
        'position': UserSession.position,
        'profile_photo_url': UserSession.profilePhotoUrl,
      };
    });
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _loading = true;
    });

    try {
      final res = await _api.getProfile();
      if (kDebugMode) {
        debugPrint('GET profile response: $res');
      }
      final root = res;
      final data = root['data'] is Map<String, dynamic> ? (root['data'] as Map<String, dynamic>) : const <String, dynamic>{};
      final student = data['student'] is Map<String, dynamic>
          ? (data['student'] as Map<String, dynamic>)
          : (root['student'] is Map<String, dynamic> ? (root['student'] as Map<String, dynamic>) : const <String, dynamic>{});
      final user = data['user'] is Map<String, dynamic>
          ? (data['user'] as Map<String, dynamic>)
          : (root['user'] is Map<String, dynamic> ? (root['user'] as Map<String, dynamic>) : const <String, dynamic>{});

      if (data.isNotEmpty) {
        UserSession.setFromResponse(data);
      }
      UserSession.setFromResponse(root);

      final merged = <String, dynamic>{};
      merged.addAll(_profile ?? const <String, dynamic>{});
      if (data.isNotEmpty) merged.addAll(data);
      merged.addAll(root);
      if (data.isNotEmpty) merged['data'] = data;
      if (student.isNotEmpty) merged['student'] = student;
      if (user.isNotEmpty) merged['user'] = user;

      setState(() {
        _profile = merged;
      });
    } catch (_) {
      // keep existing
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = _resolveFullName();
    final role = _readString('role');
    final studentId = _readString('student_id').isNotEmpty ? _readString('student_id') : (UserSession.studentId ?? '');
    final photoUrl = _resolvePhotoUrl();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(''),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B6CFF), Color(0xFFFFF176)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withValues(alpha: 0.86),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isNotEmpty ? null : const Icon(Icons.person, size: 36, color: Colors.black87),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName.isEmpty ? 'User' : fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              role.isEmpty ? 'Student' : role,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _changePhoto,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black12),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.photo_camera_outlined, size: 16),
                        label: const Text('Change Photo'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _ProfileField(label: 'Full Name', value: fullName),
              _ProfileField(label: 'Course', value: _readFirst(const ['course', 'program', 'department'])),
              _ProfileField(label: 'Email', value: _readFirst(const ['email'])),
              _ProfileField(label: 'Created At', value: _readFirst(const ['created_at', 'createdAt', 'date_joined', 'dateJoined'])),
              _ProfileField(label: 'Student ID', value: studentId),
              _ProfileField(label: 'Year & Section', value: _resolveYearSection()),
              _ProfileField(label: 'Phone No.', value: _readFirst(const ['phone_number', 'phoneNumber', 'phone', 'mobile', 'contact', 'contact_no', 'contactNo'])),
            ],
          ),
        ),
      ),
    );
  }

  String _readString(String key) {
    final v = _lookup(key);
    if (v == null) return '';
    return v.toString().trim();
  }

  String _readFirst(List<String> keys) {
    for (final k in keys) {
      final v = _readString(k);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  Object? _lookup(String key) {
    final top = _profile;
    if (top == null) return null;
    if (top.containsKey(key) && top[key] != null) return top[key];

    final data = top['data'];
    if (data is Map<String, dynamic> && data.containsKey(key) && data[key] != null) return data[key];

    final student = top['student'];
    if (student is Map<String, dynamic> && student.containsKey(key) && student[key] != null) return student[key];

    final user = top['user'];
    if (user is Map<String, dynamic> && user.containsKey(key) && user[key] != null) return user[key];

    return null;
  }

  String _resolveYearSection() {
    final direct = _readFirst(const ['year_section', 'yearSection', 'year_and_section', 'yearAndSection']);
    if (direct.isNotEmpty) return direct;

    final year = _readFirst(const ['year', 'year_level', 'yearLevel']);
    final section = _readFirst(const ['section', 'sec']);
    final combined = [year, section].where((p) => p.trim().isNotEmpty).join(' ').trim();
    return combined;
  }

  String _resolveFullName() {
    final direct = _readString('full_name');
    if (direct.isNotEmpty) return direct;
    final sessionName = (UserSession.fullName ?? '').trim();
    if (sessionName.isNotEmpty) return sessionName;

    // Try build from split fields if backend returns student info.
    final first = _readString('first_name');
    final middle = _readString('middle_name');
    final last = _readString('last_name');
    final built = [first, middle, last].where((p) => p.trim().isNotEmpty).join(' ').trim();
    return built;
  }

  String _resolvePhotoUrl() {
    final direct = _readFirst(const ['profile_photo_url', 'profilePhotoUrl', 'photo_url', 'photoUrl', 'photo', 'avatar']);
    if (direct.isNotEmpty) return _cacheBust(_normalizePhotoUrl(direct));
    final sessionUrl = (UserSession.profilePhotoUrl ?? '').trim();
    if (sessionUrl.isNotEmpty) return _cacheBust(_normalizePhotoUrl(sessionUrl));
    return '';
  }

  String _normalizePhotoUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;

    // Backend might return a relative path like /media/... or media/...
    final base = ApiConfig.baseUrl;
    if (trimmed.startsWith('/')) return '$base$trimmed';
    return '$base/$trimmed';
  }

  String _cacheBust(String url) {
    if (url.isEmpty) return '';
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}t=$_photoCacheBuster';
  }

  Future<void> _changePhoto() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      final oldUrl = _resolvePhotoUrl();

      setState(() {
        _loading = true;
      });

      // Backend endpoint /api/mobile/account/profile/photo/ expects JSON { photo_url }, not a multipart file.
      // So we always upload to Cloudinary first, then persist the returned URL to the backend.
      final secureUrl = await _api.uploadImageToCloudinary(imageFile: File(picked.path));
      final setRes = await _api.setProfilePhotoUrl(photoUrl: secureUrl);
      if (kDebugMode) {
        debugPrint('POST set profile photo URL response: $setRes');
      }

      final uploadedUrl = secureUrl;

      if (uploadedUrl.isNotEmpty) {
        UserSession.profilePhotoUrl = uploadedUrl;
        setState(() {
          _photoCacheBuster = DateTime.now().millisecondsSinceEpoch;
          _profile = {
            ...?_profile,
            'profile_photo_url': uploadedUrl,
            'photo_url': uploadedUrl,
            'photo': uploadedUrl,
          };
        });
      }

      await _refreshProfile();

      // Some backends return ok=true but update the stored URL asynchronously.
      // Poll profile a few times to catch the new URL and update the avatar.
      for (var i = 0; i < 4; i++) {
        final current = _resolvePhotoUrl();
        if (current.isNotEmpty && current != oldUrl) break;
        await Future<void>.delayed(const Duration(milliseconds: 800));
        await _refreshProfile();
      }

      if (!mounted) return;

      final newUrl = _resolvePhotoUrl();
      if (newUrl.isNotEmpty && newUrl != oldUrl) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload finished, but photo URL was not returned yet')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile photo')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '—' : value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
