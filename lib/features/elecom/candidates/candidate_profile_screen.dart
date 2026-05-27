import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/config/api_config.dart';
import '../student_dashboard/utils/theme_notifier.dart';

const _premiumBlue = Color(0xFF2563EB);
const _premiumGold = Color(0xFFFACC15);
const _premiumInk = Color(0xFF0F172A);
const _premiumSub = Color(0xFF475569);
const _premiumBg = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFFFFFFF),
    Color(0xFFF4F8FF),
    Color(0xFFEAF2FF),
    Color(0xFFFDFEFF),
  ],
);

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
    final parts = [
      _t(candidate['first_name']),
      _t(candidate['middle_name']),
      _t(candidate['last_name']),
    ].where((x) => x.isNotEmpty).toList();
    return parts.isEmpty ? 'Candidate' : parts.join(' ');
  }

  String _dashIfEmpty(String s) => s.isEmpty ? '-' : s;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        final isPremiumMode = themeNotifier.isPremiumMode;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final pageBg = isPremiumMode
            ? const Color(0xFFFDFEFF)
            : isDark
            ? const Color(0xFF242526)
            : const Color(0xFFF0F2F5);
        final primaryText = isPremiumMode
            ? _premiumInk
            : isDark
            ? Colors.white
            : const Color(0xFF050505);
        final secondaryText = isPremiumMode
            ? _premiumSub
            : isDark
            ? const Color(0xFFB0B3B8)
            : const Color(0xFF65676B);
        final cardColor = isPremiumMode
            ? Colors.white.withValues(alpha: 0.88)
            : isDark
            ? const Color(0xFF18191A)
            : Colors.white;

        final name = _fullName();
        final photo = resolvedCandidatePhotoUrl(candidate['photo_url']);
        final idStr = candidate['id'] == null ? '' : candidate['id'].toString();
        final candidateType = _t(candidate['candidate_type']);
        final organization = _t(candidate['organization']);
        final position = _t(candidate['position']);
        final course = _t(candidate['program']);
        final yearSection = _t(candidate['year_section']);
        final party = _t(candidate['party_name']);
        final platformText = _t(candidate['platform']);
        final ringColor = isPremiumMode
            ? _premiumBlue
            : const Color(0xFF0C1E70);

        const double avatarRadius = 66;
        final avatarCircle = CircleAvatar(
          radius: avatarRadius,
          backgroundColor: isDark ? Colors.white12 : const Color(0xFFEAF1FF),
          backgroundImage: photo != null ? NetworkImage(photo) : null,
          child: photo == null
              ? isPremiumMode
                    ? const HugeIcon(
                        icon: HugeIcons.strokeRoundedUserCircle,
                        size: 60,
                        color: _premiumBlue,
                        strokeWidth: 1.7,
                      )
                    : Icon(Icons.person_outline, size: 60, color: secondaryText)
              : null,
        );

        Widget detail({
          required IconData fallbackIcon,
          required List<List<dynamic>> premiumIcon,
          required String label,
          required String value,
        }) {
          final v = _dashIfEmpty(_t(value));
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isPremiumMode
                    ? HugeIcon(
                        icon: premiumIcon,
                        size: 22,
                        color: _premiumBlue,
                        strokeWidth: 1.8,
                      )
                    : Icon(fallbackIcon, size: 22, color: secondaryText),
                const SizedBox(width: 14),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text: '$label: ',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
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
            backgroundColor: isPremiumMode
                ? const Color(0xFFFDFEFF)
                : isDark
                ? const Color(0xFF242526)
                : Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: primaryText),
            titleTextStyle: TextStyle(
              color: primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
            title: Text(name, overflow: TextOverflow.ellipsis),
          ),
          body: Container(
            decoration: isPremiumMode
                ? const BoxDecoration(gradient: _premiumBg)
                : null,
            child: SingleChildScrollView(
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
                              colors: isPremiumMode
                                  ? const [
                                      Color(0xFF2563EB),
                                      Color(0xFF4F8DFF),
                                      Color(0xFFFACC15),
                                    ]
                                  : const [
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
                              BoxShadow(
                                color: isPremiumMode
                                    ? _premiumBlue.withValues(alpha: 0.28)
                                    : Colors.black.withValues(
                                        alpha: isDark ? 0.35 : 0.12,
                                      ),
                                blurRadius: isPremiumMode ? 18 : 8,
                                offset: const Offset(0, 4),
                              ),
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
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      color: primaryText,
                    ),
                  ),
                  if (isPremiumMode)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (organization.isNotEmpty)
                            _PremiumChip(
                              icon: HugeIcons.strokeRoundedUniversity,
                              label: organization,
                            ),
                          if (position.isNotEmpty)
                            _PremiumChip(
                              icon: HugeIcons.strokeRoundedAward03,
                              label: position,
                            ),
                          if (party.isNotEmpty)
                            _PremiumChip(
                              icon: HugeIcons.strokeRoundedFlag01,
                              label: party,
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isPremiumMode
                            ? [
                                BoxShadow(
                                  color: _premiumBlue.withValues(alpha: 0.14),
                                  blurRadius: 24,
                                  offset: const Offset(0, 14),
                                ),
                              ]
                            : isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                        border: isPremiumMode
                            ? Border.all(
                                color: Colors.white.withValues(alpha: 0.78),
                              )
                            : isDark
                            ? Border.all(color: Colors.white12)
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isPremiumMode) ...[
                                  const HugeIcon(
                                    icon: HugeIcons.strokeRoundedUserStar01,
                                    color: _premiumBlue,
                                    size: 22,
                                    strokeWidth: 1.8,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  'Candidate profile',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: primaryText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Divider(
                              height: 22,
                              thickness: 0.8,
                              color: isPremiumMode
                                  ? _premiumBlue.withValues(alpha: 0.12)
                                  : isDark
                                  ? Colors.white12
                                  : Colors.black12,
                            ),
                            detail(
                              fallbackIcon: Icons.tag,
                              premiumIcon: HugeIcons.strokeRoundedTag01,
                              label: 'Candidate ID',
                              value: idStr,
                            ),
                            detail(
                              fallbackIcon: Icons.category_outlined,
                              premiumIcon: HugeIcons.strokeRoundedUserShield01,
                              label: 'Candidate Type',
                              value: candidateType,
                            ),
                            detail(
                              fallbackIcon: Icons.apartment_outlined,
                              premiumIcon: HugeIcons.strokeRoundedUniversity,
                              label: 'Organization',
                              value: organization,
                            ),
                            detail(
                              fallbackIcon: Icons.how_to_vote_outlined,
                              premiumIcon: HugeIcons.strokeRoundedAward03,
                              label: 'Position',
                              value: position,
                            ),
                            detail(
                              fallbackIcon: Icons.menu_book_outlined,
                              premiumIcon: HugeIcons.strokeRoundedBookOpen01,
                              label: 'Course',
                              value: course,
                            ),
                            detail(
                              fallbackIcon: Icons.school_outlined,
                              premiumIcon: HugeIcons.strokeRoundedSchool,
                              label: 'Year/Section',
                              value: yearSection,
                            ),
                            detail(
                              fallbackIcon: Icons.flag_outlined,
                              premiumIcon: HugeIcons.strokeRoundedFlag01,
                              label: 'Party Name',
                              value: party,
                            ),
                            Divider(
                              height: 28,
                              thickness: 0.8,
                              color: isPremiumMode
                                  ? _premiumBlue.withValues(alpha: 0.12)
                                  : isDark
                                  ? Colors.white12
                                  : Colors.black12,
                            ),
                            Row(
                              children: [
                                if (isPremiumMode) ...[
                                  const HugeIcon(
                                    icon: HugeIcons.strokeRoundedSparkles,
                                    color: _premiumGold,
                                    size: 20,
                                    strokeWidth: 1.8,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  'Platform',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: primaryText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _dashIfEmpty(platformText),
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.45,
                                color: primaryText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PremiumChip extends StatelessWidget {
  const _PremiumChip({required this.icon, required this.label});

  final List<List<dynamic>> icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: _premiumBlue.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, color: _premiumBlue, size: 15, strokeWidth: 1.8),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _premiumSub,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
