import 'package:flutter/material.dart';

import '../../../core/config/api_config.dart';

/// Full URL for [NetworkImage] from candidate [photo_url] from the API.
String? resolvedCandidatePhotoUrl(dynamic raw) {
  final trimmed = (raw ?? '').toString().trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http')) return trimmed;
  if (trimmed.startsWith('/')) return '${ApiConfig.baseUrl}$trimmed';
  return '${ApiConfig.baseUrl}/$trimmed';
}

class CandidateProfileScreen extends StatelessWidget {
  const CandidateProfileScreen({super.key, required this.candidate});

  final Map<String, dynamic> candidate;

  String _t(dynamic v) => (v ?? '').toString().trim();

  String _fullName() {
    final parts = [_t(candidate['first_name']), _t(candidate['middle_name']), _t(candidate['last_name'])].where((x) => x.isNotEmpty).toList();
    return parts.isEmpty ? 'Candidate' : parts.join(' ');
  }

  String _dashIfEmpty(String s) => s.isEmpty ? '—' : s;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF242526) : const Color(0xFFF0F2F5);
    final primaryText = isDark ? Colors.white : const Color(0xFF050505);
    final secondaryText = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B);

    final name = _fullName();
    final photo = resolvedCandidatePhotoUrl(candidate['photo_url']);
    final idStr = candidate['id'] == null ? '' : candidate['id'].toString();
    final platformText = _t(candidate['platform']);
    const ringColor = Color(0xFF0C1E70);

    const double avatarRadius = 66;
    Widget avatarCircle = CircleAvatar(
      radius: avatarRadius,
      backgroundColor: isDark ? Colors.white12 : const Color(0xFFEAF1FF),
      backgroundImage: photo != null ? NetworkImage(photo) : null,
      child: photo == null ? Icon(Icons.person_outline, size: 60, color: secondaryText) : null,
    );

    Widget detail(IconData iconData, String label, String value) {
      final v = _dashIfEmpty(_t(value));
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(iconData, size: 22, color: secondaryText),
            const SizedBox(width: 14),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 15, height: 1.35, color: primaryText, fontWeight: FontWeight.w600),
                  children: [
                    TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: v),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF242526) : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: primaryText),
        titleTextStyle: TextStyle(color: primaryText, fontSize: 17, fontWeight: FontWeight.w800),
        title: Text(
          name,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: const [
                          Color(0xFFFEA501),
                          Color(0xFFFEA501),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ringColor, width: 3),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: ClipOval(child: avatarCircle),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: primaryText),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18191A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                  border: isDark ? Border.all(color: Colors.white12, width: 1) : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Candidate profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: primaryText)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Divider(height: 22, thickness: 0.8, color: isDark ? Colors.white12 : Colors.black12),
                      detail(Icons.tag, 'Candidate ID', idStr),
                      detail(Icons.category_outlined, 'Candidate Type', _t(candidate['candidate_type'])),
                      detail(Icons.apartment_outlined, 'Organization', _t(candidate['organization'])),
                      detail(Icons.how_to_vote_outlined, 'Position', _t(candidate['position'])),
                      detail(Icons.menu_book_outlined, 'Course', _t(candidate['program'])),
                      detail(Icons.school_outlined, 'Year/Section', _t(candidate['year_section'])),
                      detail(Icons.flag_outlined, 'Party Name', _t(candidate['party_name'])),
                      if (_t(candidate['student_id']).isNotEmpty)
                        detail(Icons.person_search_outlined, 'Student ID', _t(candidate['student_id']))
                      else if (candidate['student_id'] != null)
                        detail(Icons.person_search_outlined, 'Student ID', '${candidate['student_id']}'),
                      Divider(height: 28, thickness: 0.8, color: isDark ? Colors.white12 : Colors.black12),
                      Text('Platform', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: primaryText)),
                      const SizedBox(height: 10),
                      Text(
                        _dashIfEmpty(platformText),
                        style: TextStyle(fontSize: 15, height: 1.45, color: primaryText, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
