import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:lottie/lottie.dart';

import '../../../core/config/api_config.dart';
import '../../../core/notifications/notification_center_store.dart';
import '../../../core/session/user_session.dart';
import '../../../core/utils/toast_service.dart';
import '../../../services/tutorial_service.dart';
import '../candidates/candidate_search_screen.dart';
import '../data/elecom_mobile_api.dart';
import '../election/election_screen.dart';
import '../election/election_transparency_screen.dart';
import '../election/receipt_screen.dart';
import '../profile/profile_screen.dart';
import '../results/results_screen.dart';
import 'utils/theme_notifier.dart';
import 'widgets/election_home_countdown.dart';
import 'widgets/election_transparency_card.dart';
import 'widgets/home_candidates_strip.dart';
import 'widgets/omnibus_code_carousel.dart';
import 'widgets/student_dashboard_appbar.dart';

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
  final GlobalKey<RefreshIndicatorState> _homeRefreshKey =
      GlobalKey<RefreshIndicatorState>();
  final ScrollController _homeScrollController = ScrollController();
  int _currentIndex = 0;
  int _resultsScreenVersion = 0;
  int _homeCountdownVersion = 0;
  int _receiptRefreshNonce = 0;
  int _voteIntentNonce = 0;
  Map<String, dynamic>? _latestReceipt;
  List<Map<String, dynamic>> _homeCandidates = <Map<String, dynamic>>[];
  Map<String, dynamic>? _ledgerSummary;
  bool _loadingLedger = false;
  bool _homeTutorialRequested = false;

  void _onReplayDashboardTutorial() {
    if (!mounted) return;
    setState(() => _currentIndex = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryScheduleHomeTutorial(force: true);
    });
  }

  Future<void> _tryScheduleHomeTutorial({bool force = false}) async {
    if (!mounted) return;
    if (_currentIndex != 0) return;
    if (_homeTutorialRequested && !force) return;
    if (!force) _homeTutorialRequested = true;
    await TutorialService.showHomeTutorialIfNeeded(
      context: context,
      force: force,
    );
  }

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
    TutorialReplayBus.register(_onReplayDashboardTutorial);
    _ensureProfileBasics();
    _loadHomeCandidates();
    _loadLedgerSummary();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryScheduleHomeTutorial();
    });
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
    await Future.wait<void>([
      _boundedRefreshTask(_ensureProfileBasics()),
      _boundedRefreshTask(NotificationCenterStore.refresh()),
      _boundedRefreshTask(_loadHomeCandidates()),
      _boundedRefreshTask(_loadLedgerSummary()),
    ], eagerError: false);
    if (mounted) {
      setState(() => _loadingLedger = false);
    }
  }

  Future<void> _boundedRefreshTask(Future<void> task) async {
    try {
      await task.timeout(const Duration(seconds: 8));
    } catch (_) {
      // Keep pull-to-refresh responsive even when one endpoint is slow/offline.
    }
  }

  Future<String> _deviceLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final ip = address.address.trim();
          if (ip.isEmpty || ip.startsWith('127.')) continue;
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              RegExp(r'^172\.(1[6-9]|2\d|3[0-1])\.').hasMatch(ip)) {
            return ip;
          }
        }
      }
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final ip = address.address.trim();
          if (ip.isNotEmpty && !ip.startsWith('127.')) return ip;
        }
      }
    } catch (_) {
      // Fall back to server-seen IP when the device IP cannot be read.
    }
    return '';
  }

  Future<bool> _ensureNetworkAuthorizedForVoting() async {
    try {
      final deviceIp = await _deviceLocalIp();
      final res = await _api.checkNetworkAccess(deviceIp: deviceIp);
      final allowed = res['allowed'] == true;
      if (allowed) return true;

      if (!mounted) return false;
      AppToast.warning(context, _networkBlockedMessage);
      return false;
    } catch (e) {
      if (!mounted) return false;
      var message = 'Network check failed. Please try again.';
      if (e is ElecomApiException) {
        final raw = e.message.trim();
        final prefix = RegExp(r'^Request failed \(\d+\):\s*');
        final clean = raw.replaceFirst(prefix, '').trim().toLowerCase();
        if (clean.contains('authorized network') ||
            clean.contains('connected to the authorized network') ||
            clean.contains('not authorized')) {
          message = _networkBlockedMessage;
        }
      }
      AppToast.warning(context, message);
      return false;
    }
  }

  String get _networkBlockedMessage =>
      'Connect to an authorized ELECOM network before voting.';

  Future<void> _openElectionForVoting() async {
    if (!await _ensureNetworkAuthorizedForVoting()) return;
    if (!mounted) return;
    setState(() {
      _voteIntentNonce++;
      _currentIndex = 1;
    });
  }

  Future<void> _loadLedgerSummary() async {
    if (mounted) {
      setState(() => _loadingLedger = true);
    }
    try {
      final res = await _api.getVoteLedger();
      final summary = res['summary'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(res['summary'] as Map<String, dynamic>)
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() => _ledgerSummary = summary);
    } catch (_) {
      if (!mounted) return;
      setState(() => _ledgerSummary = <String, dynamic>{});
    } finally {
      if (mounted) {
        setState(() => _loadingLedger = false);
      }
    }
  }

  Future<void> _triggerHomeRefreshWithEffect() async {
    if (_homeScrollController.hasClients) {
      await _homeScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }

    final indicator = _homeRefreshKey.currentState;
    if (indicator != null) {
      await indicator.show();
      return;
    }
    await _refreshHome();
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
        final shouldUsePremiumMode = isElecom && themeNotifier.isPremiumMode;
        final shouldUseDarkMode = isElecom && themeNotifier.isDarkMode;
        final dashboardTheme = shouldUsePremiumMode
            ? _premiumDashboardTheme()
            : shouldUseDarkMode
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
              isPremiumMode: shouldUsePremiumMode,
              forceDarkMode: shouldUseDarkMode && !shouldUsePremiumMode,
              titleText: _currentIndex == 4 ? 'Account' : null,
            ),
            body: shouldUsePremiumMode
                ? _PremiumDashboardBackground(
                    child: Stack(
                      children: [
                        _dashboardTabs(context),
                        if (_currentIndex == 0) const _PremiumAssistantBubble(),
                      ],
                    ),
                  )
                : _dashboardTabs(context),
            bottomNavigationBar: SafeArea(
              top: false,
              child: BottomNavigationBar(
                key: ElecomTutorialKeys.homeBottomNav,
                type: BottomNavigationBarType.fixed,
                currentIndex: _currentIndex,
                onTap: _handleBottomNavTap,
                selectedItemColor: shouldUsePremiumMode
                    ? const Color(0xFFFACC15)
                    : shouldUseDarkMode
                    ? Colors.white
                    : Colors.black,
                unselectedItemColor: shouldUsePremiumMode
                    ? const Color(0xFF2563EB)
                    : shouldUseDarkMode
                    ? Colors.white70
                    : Colors.black54,
                backgroundColor: shouldUseDarkMode
                    ? const Color(0xFF242433)
                    : Colors.white,
                items: shouldUsePremiumMode
                    ? _premiumBottomNavItems()
                    : [
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.home_outlined),
                          label: 'Home',
                        ),
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.how_to_vote_outlined),
                          label: 'Election',
                        ),
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.bar_chart_outlined),
                          label: 'Results',
                        ),
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.receipt_long_outlined),
                          label: 'Receipt',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(
                            Icons.person_outline,
                            key: ElecomTutorialKeys.homeSettings,
                          ),
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

  List<BottomNavigationBarItem> _premiumBottomNavItems() {
    return [
      BottomNavigationBarItem(
        icon: _premiumNavIcon(HugeIcons.strokeRoundedHome01),
        activeIcon: _premiumNavIcon(
          HugeIcons.strokeRoundedHome01,
          selected: true,
        ),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: _premiumNavIcon(HugeIcons.strokeRoundedCheckList),
        activeIcon: _premiumNavIcon(
          HugeIcons.strokeRoundedCheckList,
          selected: true,
        ),
        label: 'Election',
      ),
      BottomNavigationBarItem(
        icon: _premiumNavIcon(HugeIcons.strokeRoundedChartBarLine),
        activeIcon: _premiumNavIcon(
          HugeIcons.strokeRoundedChartBarLine,
          selected: true,
        ),
        label: 'Results',
      ),
      BottomNavigationBarItem(
        icon: _premiumNavIcon(HugeIcons.strokeRoundedInvoice03),
        activeIcon: _premiumNavIcon(
          HugeIcons.strokeRoundedInvoice03,
          selected: true,
        ),
        label: 'Receipt',
      ),
      BottomNavigationBarItem(
        icon: _premiumNavIcon(
          HugeIcons.strokeRoundedUserCircle,
          key: ElecomTutorialKeys.homeSettings,
        ),
        activeIcon: _premiumNavIcon(
          HugeIcons.strokeRoundedUserCircle,
          selected: true,
        ),
        label: 'Me',
      ),
    ];
  }

  Widget _premiumNavIcon(
    List<List<dynamic>> icon, {
    bool selected = false,
    Key? key,
  }) {
    final iconWidget = HugeIcon(
      key: key,
      icon: icon,
      color: const Color(0xFF2563EB),
      size: selected ? 23.5 : 22,
      strokeWidth: selected ? 2.1 : 1.75,
    );

    if (!selected) return iconWidget;

    return Container(
      width: 34,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFACC15).withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFACC15).withValues(alpha: 0.32),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: iconWidget,
    );
  }

  Future<void> _handleBottomNavTap(int i) async {
    // Clear any lingering toasts when switching tabs.
    AppToast.dismissAll();

    if (i == 0) {
      final wasOnHome = _currentIndex == 0;
      if (mounted) {
        setState(() => _currentIndex = 0);
      }

      if (wasOnHome) {
        await _triggerHomeRefreshWithEffect();
      } else {
        await _refreshHome();
      }

      if (mounted) {
        setState(() {
          // Recreate countdown widget so it pulls latest election window immediately.
          _homeCountdownVersion++;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryScheduleHomeTutorial();
      });
      return;
    }

    if (i == 1) {
      // Entering Election should force the same gates as "Vote Now":
      // enrollment check + face verification before ballot loads.
      await _openElectionForVoting();
      return;
    }

    setState(() {
      if (i == 2) {
        // Recreate ResultsScreen on every Results-tab tap
        // so charts replay animations even when already on Results.
        _resultsScreenVersion++;
      }
      if (i == 3 && _latestReceipt == null) {
        _receiptRefreshNonce++;
      }
      _currentIndex = i;
    });
  }

  Widget _dashboardTabs(BuildContext context) {
    return IndexedStack(
      index: _currentIndex,
      children: [
        _homeTab(context),
        ElectionScreen(
          voteIntentNonce: _voteIntentNonce,
          isActive: _currentIndex == 1,
          onReceiptReady: (receipt) {
            if (!mounted) return;
            setState(() {
              _latestReceipt = Map<String, dynamic>.from(receipt);
            });
          },
          onRequestTabIndex: (i) {
            if (!mounted) return;
            setState(() {
              if (i == 3 && _latestReceipt == null) {
                _receiptRefreshNonce++;
              }
              _currentIndex = i;
            });
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
        ReceiptScreen(
          initialReceipt: _latestReceipt,
          refreshNonce: _receiptRefreshNonce,
        ),
        const AccountBody(),
      ],
    );
  }

  Widget _homeTab(BuildContext context) {
    final isPremiumMode = themeNotifier.isPremiumMode;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isPremiumMode
        ? Colors.white.withValues(alpha: 0.72)
        : isDarkMode
        ? const Color(0xFF2A2A35)
        : Colors.white;
    final borderColor = isPremiumMode
        ? const Color(0xFF2563EB).withValues(alpha: 0.12)
        : isDarkMode
        ? Colors.white12
        : Colors.black12;
    final subtitleColor = isPremiumMode
        ? const Color(0xFF64748B)
        : isDarkMode
        ? Colors.white70
        : Colors.black54;
    final titleColor = isPremiumMode
        ? const Color(0xFF0F172A)
        : isDarkMode
        ? Colors.white
        : Colors.black;
    final photoUrl = _resolvePhotoUrl();
    final phoneMasked = _maskPhone(_phone);
    final emailMasked = _maskEmail(_email);

    return SafeArea(
      child: RefreshIndicator(
        key: _homeRefreshKey,
        color: isPremiumMode ? const Color(0xFF2563EB) : Colors.black,
        backgroundColor: Colors.white,
        onRefresh: _refreshHome,
        child: SingleChildScrollView(
          controller: _homeScrollController,
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
                          PageRouteBuilder<void>(
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const CandidateSearchScreen(),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) => child,
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
                          boxShadow: isPremiumMode
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withValues(alpha: 0.15),
                                    blurRadius: 26,
                                    offset: const Offset(0, 14),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    blurRadius: 8,
                                    offset: const Offset(0, -2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPremiumMode
                                  ? Iconsax.search_normal_1
                                  : Icons.search,
                              color: isPremiumMode
                                  ? const Color(0xFF60A5FA)
                                  : subtitleColor,
                            ),
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
                    Material(
                      color: cardColor,
                      elevation: isPremiumMode ? 10 : 0,
                      shadowColor: const Color(
                        0xFF2563EB,
                      ).withValues(alpha: isPremiumMode ? 0.14 : 0),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => setState(() => _currentIndex = 4),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
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
                                        : isPremiumMode
                                        ? const Color(0xFFFACC15)
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
                                          isPremiumMode
                                              ? Iconsax.profile_circle
                                              : Icons.person,
                                          color: isDarkMode
                                              ? Colors.white70
                                              : isPremiumMode
                                              ? const Color(0xFF2563EB)
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
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElectionHomeCountdown(
                      key: ValueKey<int>(_homeCountdownVersion),
                      orgName: widget.orgName,
                      embeddedInProfileCard: false,
                      isPremiumMode: isPremiumMode,
                      tutorialPrimaryActionKey:
                          ElecomTutorialKeys.homePrimaryAction,
                      onVoteNow: _openElectionForVoting,
                      onViewResults: () {
                        setState(() {
                          _resultsScreenVersion++;
                          _currentIndex = 2;
                        });
                      },
                      onViewReceipt: () {
                        setState(() {
                          if (_latestReceipt == null) {
                            _receiptRefreshNonce++;
                          }
                          _currentIndex = 3;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    HomeCandidatesStrip(
                      candidates: _homeCandidates,
                      isDarkMode: isDarkMode && !isPremiumMode,
                      isPremiumMode: isPremiumMode,
                    ),
                    const SizedBox(height: 18),
                    const OmnibusCodeCarousel(),
                    const SizedBox(height: 14),
                    Container(
                      key: ElecomTutorialKeys.homeReports,
                      child: ElectionTransparencyCard(
                        summary: _ledgerSummary,
                        isLoading: _loadingLedger,
                        isPremiumMode: isPremiumMode,
                        onTapViewLedger: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ElectionTransparencyScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    TutorialReplayBus.unregister();
    _homeScrollController.dispose();
    super.dispose();
  }

  // (previous _displayName removed; home tab now uses profile summary row)
}

ThemeData _premiumDashboardTheme() {
  const royalBlue = Color(0xFF2563EB);
  const gold = Color(0xFFFACC15);
  const ink = Color(0xFF0F172A);
  const surface = Color(0xFFFFFFFF);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: royalBlue,
          brightness: Brightness.light,
        ).copyWith(
          primary: royalBlue,
          secondary: gold,
          surface: surface,
          onSurface: ink,
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF8FAFC),
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardColor: surface.withValues(alpha: 0.86),
    iconTheme: const IconThemeData(color: royalBlue, size: 24),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: gold),
  );
}

class _PremiumDashboardBackground extends StatelessWidget {
  const _PremiumDashboardBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF4F8FF),
            Color(0xFFEAF2FF),
            Color(0xFFDCEAFF),
            Color(0xFFFFFFFF),
          ],
          stops: [0, 0.42, 0.68, 0.84, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -58,
            child: _PremiumGlow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.24),
              size: 240,
            ),
          ),
          Positioned(
            top: 70,
            left: 60,
            child: _PremiumGlow(
              color: Colors.white.withValues(alpha: 0.62),
              size: 170,
            ),
          ),
          Positioned(
            top: 285,
            left: -78,
            child: _PremiumGlow(
              color: const Color(0xFFFACC15).withValues(alpha: 0.24),
              size: 220,
            ),
          ),
          Positioned(
            bottom: -80,
            right: -86,
            child: _PremiumGlow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              size: 260,
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _PremiumDotPatternPainter()),
          ),
          child,
        ],
      ),
    );
  }
}

class _PremiumGlow extends StatelessWidget {
  const _PremiumGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _PremiumDotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.055)
      ..style = PaintingStyle.fill;
    const spacing = 13.0;
    for (double y = 18; y < size.height; y += spacing) {
      for (double x = 10; x < size.width; x += spacing) {
        final inCorner =
            (x < 110 && y < 120) ||
            (x > size.width - 126 && y > size.height - 190);
        if (inCorner) {
          canvas.drawCircle(Offset(x, y), 0.75, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PremiumAssistantBubble extends StatelessWidget {
  const _PremiumAssistantBubble();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 10,
      bottom: 46,
      child: Semantics(
        label: 'AI assistant',
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => AppToast.info(context, 'EleVote is coming soon.'),
          child: SizedBox(
            width: 84,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  padding: EdgeInsets.zero,
                  decoration: BoxDecoration(shape: BoxShape.circle),
                  child: Lottie.asset(
                    'assets/Robot-Bot 3D.json',
                    fit: BoxFit.contain,
                    repeat: true,
                    animate: true,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.smart_toy_outlined,
                        color: Color(0xFF2563EB),
                        size: 34,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Need question?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                        ),
                      ),
                      Text(
                        'EleVote',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
