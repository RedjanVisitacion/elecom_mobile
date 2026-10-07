import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:lottie/lottie.dart';

import '../../../app/app.dart';
import '../../../core/config/api_config.dart';
import '../../../core/notifications/notification_center_store.dart';
import '../../../core/session/elevote_preferences.dart';
import '../../../core/session/user_session.dart';
import '../../../core/utils/toast_service.dart';
import '../../../services/tutorial_service.dart';
import '../candidates/all_candidates_screen.dart';
import '../candidates/candidate_filing_screen.dart';
import '../data/elecom_mobile_api.dart';
import '../elevote/elevote_chat_screen.dart';
import '../election/election_screen.dart';
import '../election/election_transparency_screen.dart';
import '../election/receipt_screen.dart';
import '../profile/profile_screen.dart';
import '../results/results_screen.dart';
import 'utils/theme_notifier.dart';
import 'widgets/candidate_application_promo.dart';
import 'widgets/calendar_events_card.dart';
import 'widgets/election_home_countdown.dart';
import 'widgets/election_transparency_card.dart';
import 'widgets/home_candidates_strip.dart';
import 'widgets/omnibus_code_carousel.dart';
import 'widgets/student_dashboard_appbar.dart';
import '../candidates/candidate_search_screen.dart';
import '../profile/notifications_screen.dart';

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

class _StudentDashboardState extends State<StudentDashboard>
    with RouteAware, WidgetsBindingObserver {
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
  int _totalVoters = 0;
  int _totalCandidates = 0;
  bool? _hasVoted;
  List<Map<String, dynamic>> _calendarEvents = <Map<String, dynamic>>[];
  Timer? _calendarPollTimer;
  bool _loadingCalendarEvents = false;
  bool _appResumed = true;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  bool _homeTutorialRequested = false;
  bool _dashboardRouteVisible = true;
  bool _assistantVisibleOnHome = EleVotePreferences.enabledNotifier.value;
  int _assistantAnimationNonce = 0;
  PageRoute<dynamic>? _dashboardRoute;

  void _onReplayDashboardTutorial() {
    if (!mounted) return;
    setState(() => _currentIndex = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryScheduleHomeTutorial(force: true);
    });
  }

  void _handleAssistantPreferenceChanged() {
    if (!_dashboardRouteVisible) return;
    _syncAssistantBubbleVisibility();
  }

  void _syncAssistantBubbleVisibility({bool replayIfStillEnabled = false}) {
    if (!mounted) return;
    final enabled = EleVotePreferences.enabledNotifier.value;

    if (_assistantVisibleOnHome != enabled) {
      setState(() {
        _assistantVisibleOnHome = enabled;
        _assistantAnimationNonce++;
      });
      return;
    }

    if (!replayIfStillEnabled || !enabled || _currentIndex != 0) return;
    setState(() => _assistantAnimationNonce++);
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

  String _timeGreeting() {
    final hour = _now.hour;
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _displayFirstName() {
    final raw = (UserSession.fullName ?? '').trim();
    if (raw.isEmpty) {
      final role = (UserSession.role ?? '').trim().toLowerCase();
      if (role == 'admin' || role == 'superadmin') return 'Admin';
      return 'Student';
    }
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
    WidgetsBinding.instance.addObserver(this);
    _appResumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    TutorialReplayBus.register(_onReplayDashboardTutorial);
    EleVotePreferences.enabledNotifier.addListener(
      _handleAssistantPreferenceChanged,
    );
    _ensureProfileBasics();
    EleVotePreferences.load().then((_) {
      if (!mounted) return;
      _syncAssistantBubbleVisibility();
    });
    _loadHomeCandidates();
    _loadLedgerSummary();
    _loadElectionMetrics();
    _loadBallotStatus();
    _loadCalendarEvents();
    _calendarPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_appResumed && _dashboardRouteVisible && _currentIndex == 0) {
        unawaited(_loadCalendarEvents());
      }
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryScheduleHomeTutorial();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _dashboardRoute) {
      if (_dashboardRoute != null) {
        elecomRouteObserver.unsubscribe(this);
      }
      _dashboardRoute = route;
      elecomRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPush() {
    _dashboardRouteVisible = true;
  }

  @override
  void didPushNext() {
    _dashboardRouteVisible = false;
  }

  @override
  void didPopNext() {
    _dashboardRouteVisible = true;
    if (_appResumed && _currentIndex == 0) {
      unawaited(_loadCalendarEvents());
      unawaited(_loadElectionMetrics());
      unawaited(_loadBallotStatus());
    }
    _syncAssistantBubbleVisibility(replayIfStillEnabled: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (_appResumed && _dashboardRouteVisible && _currentIndex == 0) {
      unawaited(_loadCalendarEvents());
      unawaited(_loadElectionMetrics());
      unawaited(_loadBallotStatus());
    }
  }

  Future<void> _loadHomeCandidates() async {
    try {
      final list = await _api.listAllCandidates();
      if (!mounted) return;
      // Sort: USG first, then SITE → PAFE → AFPROTECHS.
      // Within each org, order by position (President → VP → … → Reps).
      list.sort(_compareCandidatesHome);
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

  static int _orgOrderHome(String org) {
    final o = org.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (o == 'USG') return 0;
    if (o.startsWith('SITE')) return 1;
    if (o.startsWith('PAFE')) return 2;
    if (o.startsWith('AFPRO')) return 3;
    return 4;
  }

  static int _positionOrderHome(String position) {
    final p = position.toLowerCase();
    if (p.contains('president') && !p.contains('vice')) return 0;
    if (p.contains('vice') && p.contains('president')) return 1;
    if (p.contains('general') && p.contains('secret')) return 2;
    if (p.contains('associate') && p.contains('secret')) return 3;
    if (p.contains('treasurer') || p.contains('treas')) return 4;
    if (p.contains('auditor') || p.contains('audit')) return 5;
    if (p.contains('public information') ||
        p.contains('p.i.o') ||
        p.contains('pio'))
      return 6;
    if (p.contains('representative') || p.contains('rep')) return 7;
    return 8;
  }

  static int _compareCandidatesHome(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final orgA = _orgOrderHome((a['organization'] ?? '').toString());
    final orgB = _orgOrderHome((b['organization'] ?? '').toString());
    if (orgA != orgB) return orgA.compareTo(orgB);
    final posA = _positionOrderHome((a['position'] ?? '').toString());
    final posB = _positionOrderHome((b['position'] ?? '').toString());
    return posA.compareTo(posB);
  }

  Future<void> _refreshHome() async {
    await Future.wait<void>([
      _boundedRefreshTask(_ensureProfileBasics()),
      _boundedRefreshTask(NotificationCenterStore.refresh()),
      _boundedRefreshTask(_loadHomeCandidates()),
      _boundedRefreshTask(_loadLedgerSummary()),
      _boundedRefreshTask(_loadElectionMetrics()),
      _boundedRefreshTask(_loadBallotStatus()),
      _boundedRefreshTask(_loadCalendarEvents()),
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
      _currentIndex = 2;
    });
  }

  void _openCandidateApplicationInfo() {
    Navigator.of(context).push(
      PageRouteBuilder<bool>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CandidateFilingScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            child,
      ),
    );
  }

  Future<void> _loadElectionMetrics() async {
    try {
      final res = await _api.getElectionWindow();
      final metrics = res['metrics'] is Map<String, dynamic>
          ? res['metrics'] as Map<String, dynamic>
          : const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _totalVoters = (metrics['total_voters'] as num?)?.toInt() ?? 0;
        _totalCandidates = (metrics['total_candidates'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      // silently ignore; stats stay at 0
    }
  }

  Future<void> _loadBallotStatus() async {
    try {
      final status = await _api.getVoteStatus();
      if (!mounted || status['ok'] != true) return;
      setState(() {
        _hasVoted = status['voted'] == true;
        if (_hasVoted == false) _latestReceipt = null;
      });
    } catch (_) {
      // Preserve the last known status when offline.
    }
  }

  Future<void> _loadCalendarEvents() async {
    if (!mounted || _loadingCalendarEvents) return;
    _loadingCalendarEvents = true;
    try {
      final events = await _api.getCalendarEvents();
      if (!mounted) return;
      if (jsonEncode(events) == jsonEncode(_calendarEvents)) return;
      setState(() => _calendarEvents = events);
    } catch (_) {
      // Keep the last successful list; the next poll retries automatically.
    } finally {
      _loadingCalendarEvents = false;
    }
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
            appBar: _currentIndex == 0
                ? null
                : StudentDashboardAppBar.build(
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
                        if (_currentIndex == 0)
                          _AnimatedPremiumAssistantBubble(
                            visible: _assistantVisibleOnHome,
                            animationNonce: _assistantAnimationNonce,
                          ),
                      ],
                    ),
                  )
                : _dashboardTabs(context),
            bottomNavigationBar: _buildBottomNav(
              context: context,
              isPremiumMode: shouldUsePremiumMode,
              isDarkMode: shouldUseDarkMode,
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Globe-style info card — overlaps below the banner, shows user details
  // and voter stats (Total Voters / Already Voted).
  // ---------------------------------------------------------------------------
  Widget _buildInfoCard(BuildContext context) {
    final isPremiumMode = themeNotifier.isPremiumMode;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDarkMode ? const Color(0xFF2A2A35) : Colors.white;
    final nameColor = isDarkMode
        ? const Color(0xFF60A5FA)
        : const Color(0xFF2563EB);
    final subColor = isDarkMode
        ? const Color(0xFF60A5FA).withValues(alpha: 0.70)
        : const Color(0xFF2563EB).withValues(alpha: 0.60);
    final dividerColor = isDarkMode
        ? const Color(0xFF60A5FA).withValues(alpha: 0.25)
        : const Color(0xFF2563EB).withValues(alpha: 0.18);

    final now = _now;
    final dateStr =
        '${_monthName(now.month)} ${now.day}, ${now.year}  ${_formatTime(now)}';

    final phoneMasked = _maskPhone(_phone);
    final emailMasked = _maskEmail(_email);

    return Container(
      margin: EdgeInsets.zero,
      height: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.20 : 0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          children: [
            // ── Blue accent bar ──────────────────────────────────────────
            Container(
              height: 5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0C1E70), Color(0xFF1D4ED8)],
                ),
              ),
            ),
            // ── Card content ─────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Name + date + contact
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _displayFirstName(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: nameColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      height: 1.1,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      color: subColor,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Image.asset(
                              'assets/USTP_ELECOM_ICON.png',
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ],
                        ),
                        if (phoneMasked.isNotEmpty ||
                            emailMasked.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          if (phoneMasked.isNotEmpty)
                            Text(
                              phoneMasked,
                              style: TextStyle(
                                color: subColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (emailMasked.isNotEmpty)
                            Text(
                              emailMasked,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: subColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ],
                    ),
                    // Divider + stats
                    Column(
                      children: [
                        Divider(color: dividerColor, height: 1),
                        const SizedBox(height: 8),
                        IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(
                                child: _statTile(
                                  context: context,
                                  icon: Iconsax.people,
                                  iconColor: isDarkMode
                                      ? const Color(0xFF60A5FA)
                                      : const Color(0xFF2563EB),
                                  value: _totalVoters > 0
                                      ? _totalVoters.toString()
                                      : '—',
                                  label: 'Total Voters',
                                  nameColor: nameColor,
                                  subColor: subColor,
                                ),
                              ),
                              VerticalDivider(color: dividerColor, width: 1),
                              Expanded(
                                child: _statTile(
                                  context: context,
                                  icon: Iconsax.profile_2user,
                                  iconColor: isDarkMode
                                      ? const Color(0xFF60A5FA)
                                      : const Color(0xFF2563EB),
                                  value: _totalCandidates > 0
                                      ? _totalCandidates.toString()
                                      : '—',
                                  label: 'Total Candidates',
                                  nameColor: nameColor,
                                  subColor: subColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required Color nameColor,
    required Color subColor,
  }) {
    // Parse value for progress arc (cap at reasonable max for visual fill)
    final intVal = int.tryParse(value) ?? 0;
    // Use a soft fill — cap at 2000 for voters, 100 for candidates
    final maxVal = label.contains('Voter') ? 2000.0 : 100.0;
    final progress = intVal > 0 ? (intVal / maxVal).clamp(0.0, 1.0) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(60, 60),
                painter: _ArcPainter(
                  progress: progress,
                  color: iconColor,
                  trackColor: iconColor.withValues(alpha: 0.12),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: 14),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: TextStyle(
                      color: nameColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: subColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _monthName(int m) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[m - 1];
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$min $period';
  }

  // ---------------------------------------------------------------------------
  // Custom home header banner — full-width USTP campus photo with dark overlay,
  // avatar + greeting on the left, search + notification on the right.
  // ---------------------------------------------------------------------------
  Widget _buildHomeHeader(BuildContext context) {
    final isPremiumMode = themeNotifier.isPremiumMode;
    final photoUrl = _resolvePhotoUrl();

    return Stack(
      children: [
        // ── Background image ────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 170,
          child: Image.asset(
            'assets/USTP PICS/USTP_FRONT.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF0C1E70)),
          ),
        ),
        // ── Dark gradient overlay ───────────────────────────────────────
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.30),
                ],
              ),
            ),
          ),
        ),
        // ── Content ─────────────────────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                GestureDetector(
                  onTap: () => setState(() => _currentIndex = 4),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFACC15),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white12,
                          backgroundImage: photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          onBackgroundImageError: photoUrl.isNotEmpty
                              ? (e, s) {}
                              : null,
                          child: photoUrl.isNotEmpty
                              ? null
                              : const Icon(
                                  Icons.person,
                                  color: Colors.white70,
                                  size: 26,
                                ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4B5563),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white30,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Greeting text
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentIndex = 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _timeGreeting(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w400,
                            fontSize: 11,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          _displayFirstName(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Search button
                IconButton(
                  tooltip: 'Search candidates',
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder<void>(
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                        pageBuilder: (c, a, b) => const CandidateSearchScreen(),
                        transitionsBuilder: (c, a, b, child) => child,
                      ),
                    );
                  },
                  icon: const Icon(Icons.search, color: Colors.white, size: 24),
                ),
                // Notification bell
                ValueListenableBuilder<int>(
                  valueListenable: NotificationCenterStore.unreadCount,
                  builder: (context, unreadCount, _) {
                    return IconButton(
                      tooltip: 'Notifications',
                      onPressed: () {
                        Navigator.of(context).push(
                          PageRouteBuilder<void>(
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                            pageBuilder: (c, a, b) =>
                                const NotificationsScreen(),
                            transitionsBuilder: (c, a, b, child) => child,
                          ),
                        );
                      },
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.notifications_none,
                            color: Colors.white,
                            size: 24,
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unreadCount > 99
                                      ? '99+'
                                      : unreadCount.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ELECOM bottom navigation bar — DITO-style flat bar, oversized centre item.
  //
  // Layout (5 items, equal flex):
  //   Home | Results | [VOTE — larger icon] | Receipt | Me
  //
  // The Vote item uses a circular container with a gold background and a white
  // fingerprint icon.  Its icon is ~1.5× taller than the others so it peeks
  // above the row mid-line while the label stays on the same baseline.
  // The bar is a plain white rectangle with rounded top corners and a soft
  // top-edge shadow — no notch, no FAB, no CustomPainter.
  // ---------------------------------------------------------------------------
  Widget _buildBottomNav({
    required BuildContext context,
    required bool isPremiumMode,
    required bool isDarkMode,
  }) {
    // ── Colours ───────────────────────────────────────────────────────────
    const Color elecomBlue = Color(0xFF2563EB);
    const Color elecomGold = Color(0xFFFACC15);
    const Color darkSurface = Color(0xFF1E1E2E);

    final Color barBg = isDarkMode ? darkSurface : Colors.white;

    final Color activeColor = isPremiumMode
        ? elecomGold
        : isDarkMode
        ? Colors.white
        : elecomBlue;

    final Color inactiveColor = isDarkMode
        ? const Color(0xFF60A5FA).withValues(alpha: 0.60)
        : const Color(0xFF2563EB).withValues(alpha: 0.55);

    final Color shadowColor = isDarkMode
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.08);

    // ── Regular nav item ──────────────────────────────────────────────────
    Widget navItem(IconData icon, String label, int idx, {Key? iconKey}) {
      final bool active = _currentIndex == idx;
      final Color c = active ? activeColor : inactiveColor;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleBottomNavTap(idx),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(icon, key: iconKey, color: c, size: 24),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: c,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Premium variant uses HugeIcons.
    Widget premiumNavItem(
      List<List<dynamic>> icon,
      String label,
      int idx, {
      Key? iconKey,
    }) {
      final bool active = _currentIndex == idx;
      final Color c = active ? activeColor : inactiveColor;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleBottomNavTap(idx),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.max,
              children: [
                _premiumNavIcon(icon, selected: active, key: iconKey),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: c,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Centre Vote item ──────────────────────────────────────────────────
    // elecom.png has large transparent margins around the actual logo mark.
    // Sizing the Image widget to 88×88 makes the *visible* logo fill roughly
    // the same area the previous yellow circle (~56 px) occupied.
    // When active (tab index == 2), a gold circular border rings the logo.
    final bool voteActive = _currentIndex == 2;
    final Widget voteItem = Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleBottomNavTap(2),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Transform.translate(
            offset: const Offset(0, -8),
            child: Container(
              width: 156,
              height: 156,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: voteActive
                      ? const Color(0xFFFACC15)
                      : Colors.transparent,
                  width: 8,
                ),
              ),
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Transform.scale(
                  scale: 1.45,
                  child: Image.asset(
                    'assets/elecom.png',
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.how_to_vote_rounded,
                      color: voteActive ? activeColor : inactiveColor,
                      size: 56,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: barBg,
              borderRadius: BorderRadius.zero,
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              height: 64,
              child: Row(
                key: ElecomTutorialKeys.homeBottomNav,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Home
                  isPremiumMode
                      ? premiumNavItem(HugeIcons.strokeRoundedHome01, 'Home', 0)
                      : navItem(Icons.home_rounded, 'Home', 0),
                  // Results
                  isPremiumMode
                      ? premiumNavItem(
                          HugeIcons.strokeRoundedChartBarLine,
                          'Results',
                          1,
                        )
                      : navItem(Icons.bar_chart_rounded, 'Results', 1),
                  // Vote — centre oversized item
                  voteItem,
                  // Receipt
                  isPremiumMode
                      ? premiumNavItem(
                          HugeIcons.strokeRoundedInvoice03,
                          'Receipt',
                          3,
                        )
                      : navItem(Icons.receipt_long_rounded, 'Receipt', 3),
                  // Me
                  isPremiumMode
                      ? premiumNavItem(
                          HugeIcons.strokeRoundedUserCircle,
                          'Me',
                          4,
                          iconKey: ElecomTutorialKeys.homeSettings,
                        )
                      : navItem(
                          Icons.person_rounded,
                          'Me',
                          4,
                          iconKey: ElecomTutorialKeys.homeSettings,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumNavIcon(
    List<List<dynamic>> icon, {
    bool selected = false,
    Key? key,
  }) {
    const Color elecomBlue = Color(0xFF2563EB);
    const Color elecomGold = Color(0xFFFACC15);

    final Color iconColor = selected
        ? elecomBlue
        : const Color(0xFF2563EB).withValues(alpha: 0.55);

    final iconWidget = HugeIcon(
      key: key,
      icon: icon,
      color: iconColor,
      size: selected ? 23.0 : 22.0,
      strokeWidth: selected ? 2.0 : 1.7,
    );

    if (!selected) return iconWidget;

    // Active state: subtle gold pill behind the icon.
    return Container(
      width: 36,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: elecomGold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
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
      // Recreate ResultsScreen on every Results-tab tap
      // so charts replay animations even when already on Results.
      setState(() {
        _resultsScreenVersion++;
        _currentIndex = 1;
      });
      return;
    }

    if (i == 2) {
      // Entering Election should force the same gates as "Vote Now":
      // enrollment check + face verification before ballot loads.
      await _openElectionForVoting();
      return;
    }

    setState(() {
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
        KeyedSubtree(
          key: ValueKey<int>(_resultsScreenVersion),
          child: const ResultsScreen(),
        ),
        ElectionScreen(
          voteIntentNonce: _voteIntentNonce,
          isActive: _currentIndex == 2,
          onReceiptReady: (receipt) {
            if (!mounted) return;
            setState(() {
              _latestReceipt = Map<String, dynamic>.from(receipt);
              _hasVoted = true;
            });
            unawaited(_loadElectionMetrics());
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
      top: false,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Sliding cards: Profile ↔ Election Countdown ──────────
                  _SlidingCardStack(
                    profileCard: _buildInfoCard(context),
                    countdownCard: ElectionHomeCountdown(
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
                          _currentIndex = 1;
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
                    header: _buildHomeHeader(context),
                    isDarkMode: isDarkMode && !isPremiumMode,
                    isPremiumMode: isPremiumMode,
                  ),
                  // ── Rest of home content ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CalendarEventsCard(
                          events: _calendarEvents,
                          isPremiumMode: isPremiumMode,
                          isDarkMode: isDarkMode && !isPremiumMode,
                        ),
                        const SizedBox(height: 10),
                        HomeCandidatesStrip(
                          candidates: _homeCandidates,
                          isDarkMode: isDarkMode && !isPremiumMode,
                          isPremiumMode: isPremiumMode,
                          onViewAll: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AllCandidatesScreen(
                                preloaded: _homeCandidates,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CandidateApplicationPromo(
                          isDarkMode: isDarkMode && !isPremiumMode,
                          isPremiumMode: isPremiumMode,
                          onApplyNow: _openCandidateApplicationInfo,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _calendarPollTimer?.cancel();
    _clockTimer?.cancel();
    TutorialReplayBus.unregister();
    elecomRouteObserver.unsubscribe(this);
    EleVotePreferences.enabledNotifier.removeListener(
      _handleAssistantPreferenceChanged,
    );
    _homeScrollController.dispose();
    super.dispose();
  }

  // (previous _displayName removed; home tab now uses profile summary row)
}

// ── Sliding card stack: Profile card ↔ Election Countdown ────────────────────
/// Shows the header banner once, with two swipeable cards overlapping it.
/// Swiping left reveals the Election Countdown; swiping right reveals the
/// Profile card.  A page-dot indicator sits below the cards.
class _SlidingCardStack extends StatefulWidget {
  const _SlidingCardStack({
    required this.profileCard,
    required this.countdownCard,
    required this.header,
    required this.isDarkMode,
    required this.isPremiumMode,
  });

  final Widget profileCard;
  final Widget countdownCard;
  final Widget header;
  final bool isDarkMode;
  final bool isPremiumMode;

  @override
  State<_SlidingCardStack> createState() => _SlidingCardStackState();
}

class _SlidingCardStackState extends State<_SlidingCardStack> {
  final PageController _pageController = PageController();
  int _page = 0;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    // Auto-slide every 30 seconds — slow and unobtrusive
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_page + 1) % 2;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Color get _dotActive =>
      widget.isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  Color get _dotInactive =>
      (widget.isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
          .withValues(alpha: 0.25);

  // Single card height shared by BOTH slides.
  // Must be >= the countdown card's natural content height to prevent overflow.
  static const double _cardH = 235.0;

  @override
  Widget build(BuildContext context) {
    // stackH = banner overlap (140) + card height + dots area (12)
    const double stackH = 140 + _cardH + 12;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: stackH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Banner — full-width photo, greeting, icons
              Positioned(top: 0, left: 0, right: 0, child: widget.header),

              // PageView: fixed position, fixed height
              Positioned(
                top: 140,
                left: 0,
                right: 0,
                height: _cardH,
                child: ClipRect(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      // Slide 0 — Profile card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          maxHeight: _cardH,
                          child: widget.profileCard,
                        ),
                      ),
                      // Slide 1 — Election countdown
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          maxHeight: _cardH,
                          child: widget.countdownCard,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Dots — pinned at bottom of stack, always same position
              Positioned(
                bottom: 2,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(2, (i) {
                    final active = i == _page;
                    return GestureDetector(
                      onTap: () => _pageController.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: active ? 14 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: active ? _dotActive : _dotInactive,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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

class _AnimatedPremiumAssistantBubble extends StatefulWidget {
  const _AnimatedPremiumAssistantBubble({
    required this.visible,
    required this.animationNonce,
  });

  final bool visible;
  final int animationNonce;

  @override
  State<_AnimatedPremiumAssistantBubble> createState() =>
      _AnimatedPremiumAssistantBubbleState();
}

class _AnimatedPremiumAssistantBubbleState
    extends State<_AnimatedPremiumAssistantBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<double> _turns;
  late final Animation<Offset> _offset;
  bool _renderBubble = false;

  @override
  void initState() {
    super.initState();
    _renderBubble = widget.visible;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
      reverseDuration: const Duration(milliseconds: 520),
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );
    _opacity = curved;
    _scale = Tween<double>(begin: 0.55, end: 1).animate(curved);
    _turns = Tween<double>(begin: -0.08, end: 0).animate(curved);
    _offset = Tween<Offset>(
      begin: const Offset(0.15, 0),
      end: Offset.zero,
    ).animate(curved);

    if (widget.visible) {
      _controller.value = 1;
    }
    _controller.addStatusListener((status) {
      if (status != AnimationStatus.dismissed || !_renderBubble) return;
      setState(() => _renderBubble = false);
    });
  }

  @override
  void didUpdateWidget(covariant _AnimatedPremiumAssistantBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        setState(() => _renderBubble = true);
        _controller.forward(from: 0);
      } else {
        if (_controller.value == 0) {
          _controller.value = 1;
        }
        _controller.reverse();
      }
      return;
    }

    if (widget.visible && widget.animationNonce != oldWidget.animationNonce) {
      setState(() => _renderBubble = true);
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 12,
      child: IgnorePointer(
        ignoring: !_renderBubble,
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _offset,
            child: RotationTransition(
              turns: _turns,
              child: ScaleTransition(
                scale: _scale,
                child: _renderBubble
                    ? const _PremiumAssistantBubble()
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumAssistantBubble extends StatelessWidget {
  const _PremiumAssistantBubble();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AI assistant',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder<void>(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const EleVoteChatScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        },
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
    );
  }
}

// ---------------------------------------------------------------------------
// Arc painter for the analytics-style stat tile circles
// ---------------------------------------------------------------------------
class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 6.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Full track circle
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc — starts from top (-π/2), sweeps clockwise
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.14159 / 2,
        2 * 3.14159 * progress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor;
}
