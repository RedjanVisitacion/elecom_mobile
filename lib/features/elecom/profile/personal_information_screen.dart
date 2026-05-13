import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/utils/toast_service.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/api_config.dart';
import '../../../core/notifications/local_push_service.dart';
import '../../../core/notifications/notification_center_store.dart';
import '../../../core/session/notification_preferences.dart';
import '../../../core/session/user_session.dart';
import '../data/elecom_mobile_api.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final ElecomMobileApi _api = ElecomMobileApi();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _hydrateFromSession();
    _refresh();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _hydrateFromSession() {
    _profile = {
      'full_name': UserSession.fullName,
      'student_id': UserSession.studentId,
      'profile_photo_url': UserSession.profilePhotoUrl,
    };
    _syncControllersFromProfile();
  }

  Future<void> _refresh() async {
    try {
      final res = await _api.getProfile();
      setState(() {
        _profile = res;
      });
      _syncControllersFromProfile();
    } catch (_) {
      // keep existing values
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _syncControllersFromProfile() {
    _emailController.text = _readFirst(const ['email']);
    _phoneController.text = _readFirst(
      const ['phone_number', 'phoneNumber', 'phone', 'mobile', 'contact', 'contact_no', 'contactNo'],
    );
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
    final first = _readFirst(const ['first_name', 'firstName']);
    final middle = _readFirst(const ['middle_name', 'middleName']);
    final last = _readFirst(const ['last_name', 'lastName']);
    final built = [first, middle, last].where((x) => x.trim().isNotEmpty).join(' ').trim();
    if (built.isNotEmpty) return built;
    return (UserSession.fullName ?? '').trim();
  }

  String _normalizePhotoUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    if (trimmed.startsWith('/')) return '${ApiConfig.baseUrl}$trimmed';
    return '${ApiConfig.baseUrl}/$trimmed';
  }

  String _resolvePhotoUrl() {
    final direct = _readFirst(const ['profile_photo_url', 'profilePhotoUrl', 'photo_url', 'photoUrl', 'photo', 'avatar']);
    if (direct.isNotEmpty && direct.toLowerCase() != 'null') return _normalizePhotoUrl(direct);
    final session = (UserSession.profilePhotoUrl ?? '').trim();
    if (session.isNotEmpty && session.toLowerCase() != 'null') return _normalizePhotoUrl(session);
    return '';
  }

  String _resolveYearSection() {
    final direct = _readFirst(const ['year_section', 'yearSection', 'year_and_section', 'yearAndSection']);
    if (direct.isNotEmpty) return direct;

    final year = _readFirst(const ['year', 'year_level', 'yearLevel']);
    final section = _readFirst(const ['section', 'sec']);
    final combined = [year, section].where((x) => x.trim().isNotEmpty).join(' ').trim();
    return combined;
  }

  Future<void> _changePhoto() async {
    if (!_isEditing || _saving) return;
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      setState(() {
        _saving = true;
      });

      final secureUrl = await _api.uploadImageToCloudinary(imageFile: File(picked.path));
      await _api.setProfilePhotoUrl(photoUrl: secureUrl);
      UserSession.profilePhotoUrl = secureUrl;

      setState(() {
        _profile = {
          ...?_profile,
          'profile_photo_url': secureUrl,
          'photo_url': secureUrl,
          'photo': secureUrl,
        };
      });

      if (!mounted) return;
      await _notifyProfilePhotoUpdateSuccess();
      AppToast.success(context, 'Profile photo updated.');
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, 'Failed to update profile photo.');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _applyChanges() async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });
    try {
      await _api.updateProfileDetails(
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      await _notifyProfileUpdateSuccess();
      await _refresh();
      if (!mounted) return;
      setState(() {
        _isEditing = false;
      });
      AppToast.success(context, 'Profile updated.');
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, 'Failed to update profile.');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _notifyProfileUpdateSuccess() async {
    const notifTitle = 'Personal Info Updated';
    const notifBody = 'Your personal information was updated successfully.';
    final pushEnabled = await NotificationPreferences.isPushEnabled();

    // Always persist to the backend so notifications are per-account.
    await NotificationCenterStore.add(
      title: notifTitle,
      body: notifBody,
    );

    if (pushEnabled) {
      await LocalPushService.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: notifTitle,
        body: notifBody,
      );
    }
  }

  Future<void> _notifyProfilePhotoUpdateSuccess() async {
    const notifTitle = 'Profile Photo Updated';
    const notifBody = 'Your profile photo was updated successfully.';
    final pushEnabled = await NotificationPreferences.isPushEnabled();

    // Always persist to the backend so notifications are per-account.
    await NotificationCenterStore.add(title: notifTitle, body: notifBody);

    if (pushEnabled) {
      await LocalPushService.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: notifTitle,
        body: notifBody,
      );
    }
  }

  void _cancelEditing() {
    _syncControllersFromProfile();
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;
    final cardColor = isDarkMode ? const Color(0xFF2A2A35) : Colors.white;
    final borderColor = isDarkMode ? Colors.white12 : Colors.black12;
    final accentSurface = Colors.white;
    final accentContent = Colors.black87;
    final photoUrl = _resolvePhotoUrl();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Personal Information',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: titleColor,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading || _saving
                ? null
                : () {
                    setState(() {
                      _isEditing = !_isEditing;
                    });
                  },
            icon: Icon(
              _isEditing ? Icons.close : Icons.edit_outlined,
              color: titleColor,
            ),
            tooltip: _isEditing ? 'Cancel edit' : 'Edit',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _changePhoto,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: isDarkMode ? const Color(0xFF393948) : const Color(0xFFEAF1FF),
                            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl.isNotEmpty
                                ? null
                                : Icon(
                                    Icons.person,
                                    size: 48,
                                    color: isDarkMode ? Colors.white70 : Colors.blue,
                                  ),
                          ),
                          if (_isEditing)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: accentSurface,
                                  border: Border.all(color: borderColor),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.photo_camera_outlined,
                                  color: accentContent,
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      _resolveFullName().isEmpty ? 'User' : _resolveFullName(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: titleColor,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _InfoField(
                    label: 'Email',
                    value: _readFirst(const ['email']),
                    isEditing: _isEditing,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    cardColor: cardColor,
                    borderColor: borderColor,
                  ),
                  _InfoField(
                    label: 'Created At',
                    value: _readFirst(const ['created_at', 'createdAt', 'date_joined', 'dateJoined']),
                    isEditing: false,
                    controller: null,
                    locked: true,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    cardColor: cardColor,
                    borderColor: borderColor,
                  ),
                  _InfoField(
                    label: 'Student ID',
                    value: _readFirst(const ['student_id', 'studentId', 'id_number', 'idNumber']),
                    isEditing: false,
                    controller: null,
                    locked: true,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    cardColor: cardColor,
                    borderColor: borderColor,
                  ),
                  _InfoField(
                    label: 'Year & Section',
                    value: _resolveYearSection(),
                    isEditing: false,
                    controller: null,
                    locked: true,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    cardColor: cardColor,
                    borderColor: borderColor,
                  ),
                  _InfoField(
                    label: 'Phone No.',
                    value: _readFirst(
                      const ['phone_number', 'phoneNumber', 'phone', 'mobile', 'contact', 'contact_no', 'contactNo'],
                    ),
                    isEditing: _isEditing,
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    cardColor: cardColor,
                    borderColor: borderColor,
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _saving ? null : _cancelEditing,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: borderColor),
                          foregroundColor: titleColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _applyChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentSurface,
                          foregroundColor: accentContent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: borderColor),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black87,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          _saving ? 'Applying...' : 'Apply changes',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _InfoField extends StatelessWidget {
  const _InfoField({
    required this.label,
    required this.value,
    required this.isEditing,
    required this.controller,
    required this.titleColor,
    required this.subtitleColor,
    required this.cardColor,
    required this.borderColor,
    this.locked = false,
    this.keyboardType,
  });

  final String label;
  final String value;
  final bool isEditing;
  final TextEditingController? controller;
  final Color titleColor;
  final Color subtitleColor;
  final Color cardColor;
  final Color borderColor;
  final bool locked;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: subtitleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (locked)
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: subtitleColor,
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (isEditing && controller != null)
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Enter $label',
                hintStyle: TextStyle(color: subtitleColor),
              ),
            )
          else
            Text(
              value.trim().isEmpty ? '—' : value,
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}
