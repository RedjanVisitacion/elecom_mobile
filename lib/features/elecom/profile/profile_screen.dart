import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/user_session.dart';
import '../../auth/presentation/login_screen.dart';
import '../data/elecom_mobile_api.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class AccountBody extends StatefulWidget {
  const AccountBody({super.key});

  @override
  State<AccountBody> createState() => _AccountBodyState();
}

class _AccountBodyState extends State<AccountBody> {
  final ElecomMobileApi _api = ElecomMobileApi();
  bool _loading = false;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _hydrateFromSession();
    _refresh();
  }

  void _hydrateFromSession() {
    setState(() {
      _profile = {
        'full_name': UserSession.fullName,
        'student_id': UserSession.studentId,
        'role': UserSession.role,
        'department': UserSession.department,
        'position': UserSession.position,
        'email': null,
        'profile_photo_url': UserSession.profilePhotoUrl,
      };
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
    });
    try {
      final res = await _api.getProfile();
      if (kDebugMode) {
        debugPrint('GET profile response (account): $res');
      }
      UserSession.setFromResponse(res);
      if (res['data'] is Map<String, dynamic>) {
        UserSession.setFromResponse(res['data'] as Map<String, dynamic>);
      }

      setState(() {
        _profile = res;
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

  Object? _lookup(String key) {
    final top = _profile;
    if (top == null) return null;
    if (top.containsKey(key) && top[key] != null) return top[key];

    final data = top['data'];
    if (data is Map<String, dynamic> && data.containsKey(key) && data[key] != null) return data[key];

    final user = top['user'];
    if (user is Map<String, dynamic> && user.containsKey(key) && user[key] != null) return user[key];

    final student = top['student'];
    if (student is Map<String, dynamic> && student.containsKey(key) && student[key] != null) return student[key];

    return null;
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

  String _resolveFullName() {
    final direct = _readString('full_name');
    if (direct.isNotEmpty) return direct;
    final userFirst = _readFirst(const ['first_name', 'firstName']);
    final userMiddle = _readFirst(const ['middle_name', 'middleName']);
    final userLast = _readFirst(const ['last_name', 'lastName']);
    final built = [userFirst, userMiddle, userLast].where((p) => p.trim().isNotEmpty).join(' ').trim();
    if (built.isNotEmpty) return built;
    return (UserSession.fullName ?? '').trim();
  }

  String _resolveStudentId() {
    final direct = _readFirst(const ['student_id', 'studentId', 'id_number', 'idNumber']);
    if (direct.isNotEmpty) return direct;
    return (UserSession.studentId ?? '').trim();
  }

  String _normalizePhotoUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    final base = ApiConfig.baseUrl;
    if (trimmed.startsWith('/')) return '$base$trimmed';
    return '$base/$trimmed';
  }

  String _resolvePhotoUrl() {
    final direct = _readFirst(const ['profile_photo_url', 'photo_url', 'photo', 'avatar']);
    if (direct.isNotEmpty && direct.toLowerCase() != 'null') return _normalizePhotoUrl(direct);
    final sessionUrl = (UserSession.profilePhotoUrl ?? '').trim();
    if (sessionUrl.isNotEmpty && sessionUrl.toLowerCase() != 'null') return _normalizePhotoUrl(sessionUrl);
    return '';
  }

  Future<void> _logout() async {
    ApiClient.clearSession();
    UserSession.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _showInfoDialog({required String title, required String message}) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _menuItem({required IconData icon, required String title, required VoidCallback onTap, bool destructive = false}) {
    final color = destructive ? Colors.red : Colors.black;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        trailing: Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _resolveFullName();
    final studentId = _resolveStudentId();
    final photoUrl = _resolvePhotoUrl();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: const Color(0xFFF2F2F2),
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isNotEmpty ? null : const Icon(Icons.person, size: 34, color: Colors.black87),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'User' : name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            studentId.isEmpty ? 'Student ID: —' : 'Student ID: $studentId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _menuItem(
                icon: Icons.quiz_outlined,
                title: 'FAQs',
                onTap: () => _showInfoDialog(
                  title: 'FAQs',
                  message: 'Voting FAQs will be added here.\n\nFor now: make sure you are logged in and connected to the authorized network (if required).',
                ),
              ),
              _menuItem(
                icon: Icons.how_to_vote_outlined,
                title: 'About ELECOM Voting',
                onTap: () => _showInfoDialog(
                  title: 'About ELECOM Voting',
                  message: 'ELECOM is your official voting module.\n\nCast your vote securely using your verified account.',
                ),
              ),
              _menuItem(
                icon: Icons.support_agent,
                title: 'Contact Support',
                onTap: () => _showInfoDialog(
                  title: 'Contact Support',
                  message: 'Please contact your ELECOM administrator or your campus IT support for account issues.',
                ),
              ),
              _menuItem(
                icon: Icons.star_border,
                title: 'Rate our app',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')));
                },
              ),
              _menuItem(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')));
                },
              ),
              _menuItem(
                icon: Icons.logout,
                title: 'Logout',
                destructive: true,
                onTap: _logout,
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Version 1.0.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black45, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: true,
        centerTitle: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Opacity(
            opacity: 0.85,
            child: Image.asset(
              'assets/img_text/elecom_black1.png',
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => const Text('ELECOM'),
            ),
          ),
        ),
      ),
      body: const ProfileBody(),
    );
  }
}

class ProfileBody extends StatefulWidget {
  const ProfileBody({super.key});

  @override
  State<ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<ProfileBody> {
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

    return SafeArea(
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
