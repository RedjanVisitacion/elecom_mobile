import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../features/elecom/data/elecom_mobile_api.dart';

/// SharedPreferences keys for ELECOM onboarding (login + home + voting).
class TutorialPrefs {
  TutorialPrefs._();

  static const String _kLoginDone = 'elecom_tutorial_login_v1';
  static const String _kHomeDone = 'elecom_tutorial_home_v1';
  static const String _kVotingDone = 'elecom_tutorial_voting_v1';
  static const String _kFaceEnrollmentDone =
      'elecom_tutorial_face_enrollment_v1';
  static final ElecomMobileApi _api = ElecomMobileApi();

  static Future<Map<String, bool>?> _remoteState() async {
    try {
      final res = await _api.getTutorialState();
      final raw = res['tutorial'];
      if (raw is! Map) return null;
      return <String, bool>{
        'login_done': raw['login_done'] == true,
        'home_done': raw['home_done'] == true,
        'voting_done': raw['voting_done'] == true,
      };
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveLocal({
    bool? loginDone,
    bool? homeDone,
    bool? votingDone,
  }) async {
    final p = await SharedPreferences.getInstance();
    if (loginDone != null) await p.setBool(_kLoginDone, loginDone);
    if (homeDone != null) await p.setBool(_kHomeDone, homeDone);
    if (votingDone != null) await p.setBool(_kVotingDone, votingDone);
  }

  static Future<void> _saveRemote({
    bool? loginDone,
    bool? homeDone,
    bool? votingDone,
  }) async {
    try {
      await _api.updateTutorialState(
        loginDone: loginDone,
        homeDone: homeDone,
        votingDone: votingDone,
      );
    } catch (_) {
      // Local flags still keep onboarding usable before login or while offline.
    }
  }

  static Future<bool> shouldShowLoginTutorial() async {
    final remote = await _remoteState();
    if (remote != null) return !remote['login_done']!;
    final p = await SharedPreferences.getInstance();
    return !(p.getBool(_kLoginDone) ?? false);
  }

  static Future<bool> shouldShowHomeTutorial() async {
    final remote = await _remoteState();
    if (remote != null) {
      return !remote['home_done']!;
    }
    final p = await SharedPreferences.getInstance();
    final loginDone = p.getBool(_kLoginDone) ?? false;
    final homeDone = p.getBool(_kHomeDone) ?? false;
    return loginDone && !homeDone;
  }

  static Future<bool> shouldShowVotingTutorial() async {
    final remote = await _remoteState();
    if (remote != null) {
      return !remote['voting_done']!;
    }
    final p = await SharedPreferences.getInstance();
    final loginDone = p.getBool(_kLoginDone) ?? false;
    final votingDone = p.getBool(_kVotingDone) ?? false;
    return loginDone && !votingDone;
  }

  static Future<bool> shouldShowFaceEnrollmentTutorial() async {
    final p = await SharedPreferences.getInstance();
    return !(p.getBool(_kFaceEnrollmentDone) ?? false);
  }

  static Future<void> markLoginTutorialDone() async {
    await _saveLocal(loginDone: true);
    await _saveRemote(loginDone: true);
  }

  static Future<void> markHomeTutorialDone() async {
    await _saveLocal(loginDone: true, homeDone: true);
    await _saveRemote(loginDone: true, homeDone: true);
  }

  static Future<void> markVotingTutorialDone() async {
    await _saveLocal(loginDone: true, votingDone: true);
    await _saveRemote(loginDone: true, votingDone: true);
  }

  static Future<void> markFaceEnrollmentTutorialDone() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kFaceEnrollmentDone, true);
  }

  /// Skip from login: user opts out of all onboarding hints.
  static Future<void> skipEntireOnboarding() async {
    await _saveLocal(loginDone: true, homeDone: true, votingDone: true);
    await _saveRemote(loginDone: true, homeDone: true, votingDone: true);
  }

  /// Settings → replay home tour only (keeps login phase done).
  static Future<void> resetHomeTutorialOnly() async {
    await _saveLocal(homeDone: false, votingDone: false);
    await _saveRemote(homeDone: false, votingDone: false);
  }

  static Future<bool> isFullyOnboarded() async {
    final remote = await _remoteState();
    if (remote != null) {
      return remote['login_done']! &&
          remote['home_done']! &&
          remote['voting_done']!;
    }
    final p = await SharedPreferences.getInstance();
    return (p.getBool(_kLoginDone) ?? false) &&
        (p.getBool(_kHomeDone) ?? false) &&
        (p.getBool(_kVotingDone) ?? false);
  }
}

/// Registered by [StudentDashboard]; fired from Settings "Replay tutorial".
class TutorialReplayBus {
  TutorialReplayBus._();

  static void Function()? _listener;

  static void register(void Function()? listener) => _listener = listener;

  static void unregister() => _listener = null;

  static void requestDashboardReplay() => _listener?.call();
}

/// [GlobalKey]s for coach marks (attach to target widgets).
class ElecomTutorialKeys {
  ElecomTutorialKeys._();

  static final GlobalKey loginStudentId = GlobalKey(
    debugLabel: 'tut_login_sid',
  );
  static final GlobalKey loginPassword = GlobalKey(debugLabel: 'tut_login_pw');
  static final GlobalKey loginForgot = GlobalKey(
    debugLabel: 'tut_login_forgot',
  );
  static final GlobalKey loginSubmit = GlobalKey(
    debugLabel: 'tut_login_submit',
  );

  static final GlobalKey homeBottomNav = GlobalKey(debugLabel: 'tut_home_nav');
  static final GlobalKey homeReports = GlobalKey(
    debugLabel: 'tut_home_reports',
  );
  static final GlobalKey homePrimaryAction = GlobalKey(
    debugLabel: 'tut_home_cta',
  );
  static final GlobalKey homeSettings = GlobalKey(
    debugLabel: 'tut_home_settings',
  );

  static final GlobalKey votingHeader = GlobalKey(
    debugLabel: 'tut_voting_header',
  );
  static final GlobalKey votingBallot = GlobalKey(
    debugLabel: 'tut_voting_ballot',
  );
  static final GlobalKey votingSubmit = GlobalKey(
    debugLabel: 'tut_voting_submit',
  );

  static final GlobalKey faceEnrollInfo = GlobalKey(
    debugLabel: 'tut_face_enroll_info',
  );
  static final GlobalKey faceEnrollFrame = GlobalKey(
    debugLabel: 'tut_face_enroll_frame',
  );
  static final GlobalKey faceEnrollStart = GlobalKey(
    debugLabel: 'tut_face_enroll_start',
  );
}

class TutorialService {
  TutorialService._();

  static const Color _overlay = Colors.black;
  static const double _overlayOpacity = 0.82;
  static TutorialCoachMark? _activeCoach;

  static void dismissActiveTutorial() {
    final coach = _activeCoach;
    _activeCoach = null;
    coach?.skip();
  }

  static Future<void> _waitForKeys(
    List<GlobalKey> keys, {
    int maxFrames = 12,
  }) async {
    for (var i = 0; i < maxFrames; i++) {
      final ready = keys.every((k) => k.currentContext != null);
      if (ready) return;
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  static Future<void> _waitForAnyKey(
    List<GlobalKey> keys, {
    int maxFrames = 12,
  }) async {
    for (var i = 0; i < maxFrames; i++) {
      final ready = keys.any((k) => k.currentContext != null);
      if (ready) return;
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  static bool _isKeyVisible(BuildContext context, GlobalKey key) {
    final targetContext = key.currentContext;
    if (targetContext == null) return false;
    final render = targetContext.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return false;

    final topLeft = render.localToGlobal(Offset.zero);
    final rect = topLeft & render.size;
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    final safeScreen = screen.deflate(4);
    return rect.overlaps(safeScreen) && rect.width > 0 && rect.height > 0;
  }

  static List<_TutorialStep> _visibleSteps(
    BuildContext context,
    List<_TutorialStep> steps,
  ) {
    return steps
        .where(
          (s) => s.key.currentContext != null && _isKeyVisible(context, s.key),
        )
        .toList(growable: false);
  }

  static Widget _arrowTowardTarget(ContentAlign align) {
    final icon = switch (align) {
      ContentAlign.bottom => Icons.keyboard_arrow_up_rounded,
      ContentAlign.top => Icons.keyboard_arrow_down_rounded,
      ContentAlign.left => Icons.keyboard_arrow_right_rounded,
      ContentAlign.right => Icons.keyboard_arrow_left_rounded,
      ContentAlign.custom => Icons.touch_app_rounded,
    };
    return Icon(icon, color: Colors.white, size: 36)
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(
          begin: align == ContentAlign.left || align == ContentAlign.right
              ? 0
              : -4,
          end: align == ContentAlign.left || align == ContentAlign.right
              ? 0
              : 6,
          duration: 650.ms,
          curve: Curves.easeInOut,
        )
        .moveX(
          begin: align == ContentAlign.top || align == ContentAlign.bottom
              ? 0
              : -3,
          end: align == ContentAlign.top || align == ContentAlign.bottom
              ? 0
              : 3,
          duration: 650.ms,
          curve: Curves.easeInOut,
        );
  }

  static TargetFocus _target({
    required dynamic identify,
    required GlobalKey key,
    required ContentAlign align,
    required String message,
    required bool isLast,
    required VoidCallback onSkipAll,
  }) {
    return TargetFocus(
      identify: identify,
      keyTarget: key,
      shape: ShapeLightFocus.RRect,
      radius: 14,
      enableOverlayTab: false,
      enableTargetTab: false,
      contents: [
        TargetContent(
          align: align,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          builder: (context, ctrl) {
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _arrowTowardTarget(align)),
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E24).withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: onSkipAll,
                          child: const Text(
                            'Skip tutorial',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: ctrl.next,
                          child: Text(
                            isLast ? 'Done' : 'Next',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Shows login coach marks. Call from a post-frame callback when keys are mounted.
  static Future<void> showLoginTutorialIfNeeded({
    required BuildContext context,
  }) async {
    if (!context.mounted) return;
    if (!await TutorialPrefs.shouldShowLoginTutorial()) return;

    final keys = <GlobalKey>[
      ElecomTutorialKeys.loginStudentId,
      ElecomTutorialKeys.loginPassword,
      ElecomTutorialKeys.loginForgot,
      ElecomTutorialKeys.loginSubmit,
    ];
    await _waitForKeys(keys);
    if (!context.mounted) return;
    if (keys.any((k) => k.currentContext == null)) return;

    late TutorialCoachMark coach;

    void skipAll() {
      TutorialPrefs.skipEntireOnboarding();
      coach.skip();
    }

    dismissActiveTutorial();
    coach = TutorialCoachMark(
      targets: [
        _target(
          identify: 'login_sid',
          key: ElecomTutorialKeys.loginStudentId,
          align: ContentAlign.bottom,
          message: 'Enter your Student ID here.',
          isLast: false,
          onSkipAll: skipAll,
        ),
        _target(
          identify: 'login_pw',
          key: ElecomTutorialKeys.loginPassword,
          align: ContentAlign.bottom,
          message: 'Enter your password here.',
          isLast: false,
          onSkipAll: skipAll,
        ),
        _target(
          identify: 'login_forgot',
          key: ElecomTutorialKeys.loginForgot,
          align: ContentAlign.top,
          message: 'Tap here if you forgot your password.',
          isLast: false,
          onSkipAll: skipAll,
        ),
        _target(
          identify: 'login_go',
          key: ElecomTutorialKeys.loginSubmit,
          align: ContentAlign.top,
          message: 'Tap here to login to your account.',
          isLast: true,
          onSkipAll: skipAll,
        ),
      ],
      colorShadow: _overlay,
      opacityShadow: _overlayOpacity,
      paddingFocus: 8,
      alignSkip: Alignment.topRight,
      textSkip: 'Skip',
      textStyleSkip: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
      hideSkip: true,
      pulseEnable: true,
      onSkip: () {
        _activeCoach = null;
        TutorialPrefs.skipEntireOnboarding();
        return true;
      },
      onFinish: () {
        _activeCoach = null;
        TutorialPrefs.markLoginTutorialDone();
      },
    );

    _activeCoach = coach;
    coach.show(context: context);
  }

  /// Home tab coach marks (after login phase is done).
  static Future<void> showHomeTutorialIfNeeded({
    required BuildContext context,
    bool force = false,
  }) async {
    if (!context.mounted) return;
    if (!force && !await TutorialPrefs.shouldShowHomeTutorial()) return;

    final allSteps = <_TutorialStep>[
      _TutorialStep(
        identify: 'home_nav',
        key: ElecomTutorialKeys.homeBottomNav,
        align: ContentAlign.top,
        message:
            'This menu keeps the main parts of ELECOM close: Home, Election, Results, Receipt, and your account.',
      ),
      _TutorialStep(
        identify: 'home_cta',
        key: ElecomTutorialKeys.homePrimaryAction,
        align: ContentAlign.bottom,
        message:
            'When voting is open, start here. The app will guide you through the required security checks before the ballot.',
      ),
      _TutorialStep(
        identify: 'home_reports',
        key: ElecomTutorialKeys.homeReports,
        align: ContentAlign.top,
        message:
            'Election transparency and vote ledger summaries are available here for review.',
      ),
      _TutorialStep(
        identify: 'home_settings',
        key: ElecomTutorialKeys.homeSettings,
        align: ContentAlign.top,
        message:
            'Open your account here to update settings, notifications, and replay this tutorial.',
      ),
    ];

    await _waitForAnyKey(allSteps.map((s) => s.key).toList());
    if (!context.mounted) return;
    final steps = _visibleSteps(context, allSteps);
    if (steps.isEmpty) return;

    late TutorialCoachMark coach;

    void skipHome() {
      TutorialPrefs.markHomeTutorialDone();
      coach.skip();
    }

    dismissActiveTutorial();
    coach = TutorialCoachMark(
      targets: [
        for (var i = 0; i < steps.length; i++)
          _target(
            identify: steps[i].identify,
            key: steps[i].key,
            align: steps[i].align,
            message: steps[i].message,
            isLast: i == steps.length - 1,
            onSkipAll: skipHome,
          ),
      ],
      colorShadow: _overlay,
      opacityShadow: _overlayOpacity,
      paddingFocus: 8,
      alignSkip: Alignment.topRight,
      textSkip: 'Skip',
      textStyleSkip: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
      hideSkip: true,
      pulseEnable: true,
      onSkip: () {
        _activeCoach = null;
        TutorialPrefs.markHomeTutorialDone();
        return true;
      },
      onFinish: () {
        _activeCoach = null;
        TutorialPrefs.markHomeTutorialDone();
      },
    );

    _activeCoach = coach;
    coach.show(context: context);
  }

  /// First-time voting walkthrough. Runs only once after a real ballot is visible.
  static Future<void> showVotingTutorialIfNeeded({
    required BuildContext context,
    bool force = false,
  }) async {
    if (!context.mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (!force && !await TutorialPrefs.shouldShowVotingTutorial()) return;

    final allSteps = <_TutorialStep>[
      _TutorialStep(
        identify: 'voting_header',
        key: ElecomTutorialKeys.votingHeader,
        align: ContentAlign.bottom,
        message:
            'First check your program and eligibility. The ballot only shows the positions you are allowed to vote for.',
      ),
      _TutorialStep(
        identify: 'voting_ballot',
        key: ElecomTutorialKeys.votingBallot,
        align: ContentAlign.top,
        message:
            'Choose your candidate for each position. Some representative positions may allow more than one selection.',
      ),
      _TutorialStep(
        identify: 'voting_submit',
        key: ElecomTutorialKeys.votingSubmit,
        align: ContentAlign.top,
        message:
            'Submit when ready. You will review your choices, complete face verification, and then receive a vote receipt.',
      ),
    ];

    await _waitForAnyKey(allSteps.map((s) => s.key).toList());
    if (!context.mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final steps = _visibleSteps(context, allSteps);
    if (steps.isEmpty) return;

    late TutorialCoachMark coach;

    void skipVoting() {
      TutorialPrefs.markVotingTutorialDone();
      coach.skip();
    }

    dismissActiveTutorial();
    coach = TutorialCoachMark(
      targets: [
        for (var i = 0; i < steps.length; i++)
          _target(
            identify: steps[i].identify,
            key: steps[i].key,
            align: steps[i].align,
            message: steps[i].message,
            isLast: i == steps.length - 1,
            onSkipAll: skipVoting,
          ),
      ],
      colorShadow: _overlay,
      opacityShadow: _overlayOpacity,
      paddingFocus: 8,
      alignSkip: Alignment.topRight,
      textSkip: 'Skip',
      textStyleSkip: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
      hideSkip: true,
      pulseEnable: true,
      onSkip: () {
        _activeCoach = null;
        TutorialPrefs.markVotingTutorialDone();
        return true;
      },
      onFinish: () {
        _activeCoach = null;
        TutorialPrefs.markVotingTutorialDone();
      },
    );

    _activeCoach = coach;
    coach.show(context: context);
  }

  /// Face enrollment walkthrough shown before opening the live camera.
  static Future<void> showFaceEnrollmentTutorialIfNeeded({
    required BuildContext context,
    bool force = false,
  }) async {
    if (!context.mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (!force && !await TutorialPrefs.shouldShowFaceEnrollmentTutorial()) {
      return;
    }

    final allSteps = <_TutorialStep>[
      _TutorialStep(
        identify: 'face_enroll_info',
        key: ElecomTutorialKeys.faceEnrollInfo,
        align: ContentAlign.bottom,
        message:
            'This creates your private face reference for voting verification only. It will not be shown publicly.',
      ),
      _TutorialStep(
        identify: 'face_enroll_frame',
        key: ElecomTutorialKeys.faceEnrollFrame,
        align: ContentAlign.top,
        message:
            'When the camera opens, center your face inside this frame and follow the blink instruction.',
      ),
      _TutorialStep(
        identify: 'face_enroll_start',
        key: ElecomTutorialKeys.faceEnrollStart,
        align: ContentAlign.top,
        message:
            'Tap here to open the camera and enroll your voting face reference.',
      ),
    ];

    await _waitForAnyKey(allSteps.map((s) => s.key).toList());
    if (!context.mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final steps = _visibleSteps(context, allSteps);
    if (steps.isEmpty) return;

    late TutorialCoachMark coach;

    void skipFaceEnrollment() {
      TutorialPrefs.markFaceEnrollmentTutorialDone();
      coach.skip();
    }

    dismissActiveTutorial();
    coach = TutorialCoachMark(
      targets: [
        for (var i = 0; i < steps.length; i++)
          _target(
            identify: steps[i].identify,
            key: steps[i].key,
            align: steps[i].align,
            message: steps[i].message,
            isLast: i == steps.length - 1,
            onSkipAll: skipFaceEnrollment,
          ),
      ],
      colorShadow: _overlay,
      opacityShadow: _overlayOpacity,
      paddingFocus: 8,
      alignSkip: Alignment.topRight,
      textSkip: 'Skip',
      textStyleSkip: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
      hideSkip: true,
      pulseEnable: true,
      onSkip: () {
        _activeCoach = null;
        TutorialPrefs.markFaceEnrollmentTutorialDone();
        return true;
      },
      onFinish: () {
        _activeCoach = null;
        TutorialPrefs.markFaceEnrollmentTutorialDone();
      },
    );

    _activeCoach = coach;
    coach.show(context: context);
  }
}

class _TutorialStep {
  const _TutorialStep({
    required this.identify,
    required this.key,
    required this.align,
    required this.message,
  });

  final String identify;
  final GlobalKey key;
  final ContentAlign align;
  final String message;
}
