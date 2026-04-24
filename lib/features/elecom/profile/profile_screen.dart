import 'package:flutter/material.dart';

import '../../../core/session/user_session.dart';
import '../data/elecom_mobile_api.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ElecomMobileApi _api = ElecomMobileApi();

  bool _loading = false;
  Map<String, dynamic>? _profile;

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
      };
    });
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _loading = true;
    });

    try {
      final res = await _api.getProfile();
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
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 36, color: Colors.black87),
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
                        onPressed: () {},
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
