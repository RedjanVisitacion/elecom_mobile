import 'package:flutter/material.dart';

import '../../../core/session/user_session.dart';
import '../profile/profile_screen.dart';
import '../data/elecom_mobile_api.dart';
import 'utils/theme_notifier.dart';
import 'widgets/student_dashboard_appbar.dart';
import '../candidates/candidate_search_screen.dart';
import '../election/election_screen.dart';
import '../election/receipt_screen.dart';
import '../election/election_transparency_screen.dart';
import '../results/results_screen.dart';
import 'dart:math' as math;
import '../../../core/config/api_config.dart';
import '../../../core/notifications/notification_center_store.dart';
import 'widgets/election_home_countdown.dart';
import 'widgets/home_candidates_strip.dart';
import 'widgets/omnibus_code_carousel.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({
    super.key,
    required this.orgName,
    required this.assetPath,
  });

  final String orgName;
  final String assetPath;

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final ElecomMobileApi _api = ElecomMobileApi();
  int _currentIndex = 0;
  int _resultsScreenVersion = 0;
  List<Map<String, dynamic>> _homeCandidates = <Map<String, dynamic>>[];

  String _displayFirstName() {
    final raw = (UserSession.fullName ?? '').trim();
    if (raw.isEmpty) return 'Student';
    final parts = raw
        .split(RegExp(r'\s+'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'Student';
    // Prefer "First Middle" (e.g. Redjan Phil) if available.
    if (parts.length >= 2) return '${parts[0]} ${parts[1]}';
    return parts.first;
  }

  String _maskPhone(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    // Keep digits, preserve leading + if present.
    final hasPlus = s.startsWith('+');
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 4) return s;
    final last4 = digits.substring(digits.length - 4);
    final prefix = hasPlus ? '+' : '';
    return '$prefix${digits.substring(0, math.min(3, digits.length))} *** $last4';
  }

  String _maskEmail(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    final at = s.indexOf('@');
    if (at <= 1) return s;
    final name = s.substring(0, at);
    final domain = s.substring(at);
    final keep = math.min(2, name.length);
    return '${name.substring(0, keep)}***$domain';
  }

  String _resolvePhotoUrl() {
    final url = (UserSession.profilePhotoUrl ?? '').trim();
    if (url.isEmpty || url.toLowerCase() == 'null') return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = ApiConfig.baseUrl;
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }

  String _phone = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _ensureProfileBasics();
    _loadHomeCandidates();
  }

  Future<void> _loadHomeCandidates() async {
    try {
      final list = await _api.listAllCandidates();
      if (!mounted) return;
      setState(() {
        _homeCandidates = list;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _homeCandidates = <Map<String, dynamic>>[];
      });
    }
  }

  Future<void> _refreshHome() async {
    await _ensureProfileBasics();
    await NotificationCenterStore.refresh();
    await _loadHomeCandidates();
  }

  Future<void> _ensureProfileBasics() async {
    if (mounted) {
      setState(() {
        // keep UI responsive; show no explicit loading here
      });
    }

    try {
      final res = await _api.getProfile();
      final root = res;
      final data = root['data'] is Map<String, dynamic>
          ? (root['data'] as Map<String, dynamic>)
          : const <String, dynamic>{};

      // Apply both shapes: some APIs return {ok:true, data:{...}} while others return fields at root.
      if (data.isNotEmpty) {
        UserSession.setFromResponse(data);
      }
      UserSession.setFromResponse(root);

      String readFirst(Map<String, dynamic> obj, List<String> keys) {
        for (final k in keys) {
          final v = obj[k];
          if (v == null) continue;
          final s = v.toString().trim();
          if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
        }
        return '';
      }

      final user = root['user'] is Map<String, dynamic>
          ? (root['user'] as Map<String, dynamic>)
          : const <String, dynamic>{};
      final student = root['student'] is Map<String, dynamic>
          ? (root['student'] as Map<String, dynamic>)
          : const <String, dynamic>{};

      final email = readFirst(root, const ['email']);
      final email2 = email.isNotEmpty
          ? email
          : readFirst(user, const ['email']);
      final email3 = email2.isNotEmpty
          ? email2
          : readFirst(student, const ['email']);

      final phone = readFirst(root, const [
        'phone',
        'phone_number',
        'phoneNumber',
        'contact_no',
        'contactNo',
      ]);
      final phone2 = phone.isNotEmpty
          ? phone
          : readFirst(user, const [
              'phone',
              'phone_number',
              'contact_no',
              'contactNo',
            ]);
      final phone3 = phone2.isNotEmpty
          ? phone2
          : readFirst(student, const [
              'phone_number',
              'phone',
              'contact_no',
              'contactNo',
            ]);

      if (mounted) setState(() {});
      if (mounted) {
        setState(() {
          _email = email3;
          _phone = phone3;
        });
      }
    } catch (_) {
      if (mounted) setState(() {});
    } finally {
      if (mounted) {
        setState(() {
          // done
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isElecom = widget.orgName.toUpperCase().contains('ELECOM');

    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, child) {
        final shouldUseDarkMode = isElecom && themeNotifier.isDarkMode;
        final dashboardTheme = shouldUseDarkMode
            ? ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple,
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
                scaffoldBackgroundColor: const Color(0xFF171620),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF171620),
                  foregroundColor: Colors.white,
                ),
              )
            : Theme.of(context);

        return Theme(
          data: dashboardTheme,
          child: Scaffold(
            appBar: StudentDashboardAppBar.build(
              context: context,
              isElecom: isElecom,
              titleText: _currentIndex == 4 ? 'Account' : null,
            ),
            body: IndexedStack(
              index: _currentIndex,
              children: [
                _homeTab(context),
                ElectionScreen(
                  onRequestTabIndex: (i) {
                    if (!mounted) return;
                    setState(() => _currentIndex = i);
                  },
                  onViewTransparency: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ElectionTransparencyScreen(),
                      ),
                    );
                  },
                ),
                KeyedSubtree(
                  key: ValueKey<int>(_resultsScreenVersion),
                  child: const ResultsScreen(),
                ),
                const ReceiptScreen(),
                const AccountBody(),
              ],
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: _currentIndex,
                onTap: (i) {
                  setState(() {
                    if (i == 2) {
                      // Recreate ResultsScreen on every Results-tab tap
                      // so charts replay animations even when already on Results.
                      _resultsScreenVersion++;
                    }
                    _currentIndex = i;
                  });
                },
                selectedItemColor: shouldUseDarkMode
                    ? Colors.white
                    : Colors.black,
                unselectedItemColor: shouldUseDarkMode
                    ? Colors.white70
                    : Colors.black54,
                backgroundColor: shouldUseDarkMode
                    ? const Color(0xFF242433)
                    : Colors.white,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.how_to_vote_outlined),
                    label: 'Election',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bar_chart_outlined),
                    label: 'Results',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.receipt_long_outlined),
                    label: 'Receipt',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    label: 'Me',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _homeTab(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF2A2A35) : Colors.white;
    final borderColor = isDarkMode ? Colors.white12 : Colors.black12;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    final photoUrl = _resolvePhotoUrl();
    final phoneMasked = _maskPhone(_phone);
    final emailMasked = _maskEmail(_email);

    return SafeArea(
      child: RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.white,
        onRefresh: _refreshHome,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Facebook-style search bar that navigates to search screen.
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CandidateSearchScreen(),
                          ),
                        );
                      },
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: subtitleColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Search candidates...',
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Profile row — same horizontal bounds as search bar (single outer padding only).
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.white24
                                    : const Color(0xFFFEA501),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: isDarkMode
                                  ? Colors.white12
                                  : const Color(0xFFEAF1FF),
                              backgroundImage: photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl.isNotEmpty
                                  ? null
                                  : Icon(
                                      Icons.person,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.blue,
                                      size: 28,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hi, ${_displayFirstName().toUpperCase()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    height: 1.05,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (phoneMasked.isNotEmpty)
                                  Text(
                                    phoneMasked,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      height: 1.1,
                                    ),
                                  ),
                                if (emailMasked.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    emailMasked,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 62,
                            height: 62,
                            child: Image.asset(
                              'assets/gif/Elecom Splash.gif',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElectionHomeCountdown(
                      orgName: widget.orgName,
                      embeddedInProfileCard: false,
                      onVoteNow: () {
                        setState(() => _currentIndex = 1);
                      },
                      onViewResults: () {
                        setState(() {
                          _resultsScreenVersion++;
                          _currentIndex = 2;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    HomeCandidatesStrip(
                      candidates: _homeCandidates,
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 18),
                    const OmnibusCodeCarousel(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // (previous _displayName removed; home tab now uses profile summary row)
}
