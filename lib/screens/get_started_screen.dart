import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../features/auth/presentation/login_screen.dart';

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  static const onboardingCompletedKey = 'elecom_get_started_complete_v1';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(onboardingCompletedKey) ?? false);
  }

  static Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingCompletedKey, true);
  }

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  static const _black = Color(0xFF0D1B3E);
  static const _blue = Color(0xFF135FCF);
  static const _softBlue = Color(0xFFEAF4FF);
  static const _text = Color(0xFF0D1B3E);

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    await GetStartedScreen.markComplete();
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  static const _steps = [
    _OnboardingData(
      title: 'Biometric Face Verification',
      description:
          'Cast your vote securely. Quick facial recognition verification ensures your ballot is authentic and protected.',
      kind: _IllustrationKind.security,
    ),
    _OnboardingData(
      title: 'Vote Anywhere on Campus',
      description:
          'Access your election from your phone while connected to an authorized campus network.',
      kind: _IllustrationKind.network,
    ),
    _OnboardingData(
      title: 'Instant Results',
      description:
          'Automated counting delivers reliable election results when published. Continue to login and take part in your campus election.',
      kind: _IllustrationKind.results,
    ),
  ];

  void _goToPage(int index) {
    if (_isCompleting || !_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _steps.length - 1;
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _black),
        scaffoldBackgroundColor: Colors.white,
        textSelectionTheme: const TextSelectionThemeData(cursorColor: _blue),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            const _OnboardingBackground(),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _steps.length,
                      onPageChanged: (index) =>
                          setState(() => _currentPage = index),
                      itemBuilder: (context, index) =>
                          _buildPage(_steps[index]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Its own centered lane prevents a wide login action crowding dots.
                        Align(
                          alignment: Alignment.center,
                          child: Semantics(
                            label:
                                'Onboarding step ${_currentPage + 1} of ${_steps.length}',
                            child: SizedBox(
                              height: 48,
                              child: Center(
                                child: AnimatedSmoothIndicator(
                                  key: const ValueKey('onboarding-pagination'),
                                  activeIndex: _currentPage,
                                  count: _steps.length,
                                  onDotClicked: _goToPage,
                                  effect: const ExpandingDotsEffect(
                                    dotHeight: 8,
                                    dotWidth: 8,
                                    expansionFactor: 3,
                                    spacing: 8,
                                    activeDotColor: _black,
                                    dotColor: Color(0xFFD1D5DB),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _isCompleting
                                  ? null
                                  : _completeOnboarding,
                              style: TextButton.styleFrom(
                                foregroundColor: _black,
                                minimumSize: const Size(48, 48),
                              ),
                              child: const Text(
                                'Skip',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton(
                                  key: const ValueKey('onboarding-next'),
                                  onPressed: _isCompleting
                                      ? null
                                      : isLast
                                      ? _completeOnboarding
                                      : () => _goToPage(_currentPage + 1),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _black,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(100, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 14,
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                    shape: const StadiumBorder(),
                                  ),
                                  child: Text(
                                    _isCompleting
                                        ? 'Opening…'
                                        : isLast
                                        ? 'Continue to Login'
                                        : 'Next',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  SizedBox(
                    height: (constraints.maxHeight * 0.48).clamp(160.0, 220.0),
                    child: _IllustrationCard(kind: data.kind),
                  ),
                  const SizedBox(height: 24),
                  _AnimatedTitle(data.title),
                  const SizedBox(height: 14),
                  _AnimatedBody(data.description),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.title,
    required this.description,
    required this.kind,
  });

  final String title;
  final String description;
  final _IllustrationKind kind;
}

class _AnimatedTitle extends StatelessWidget {
  const _AnimatedTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _GetStartedScreenState._text,
            fontSize: 22,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        )
        .animate(key: ValueKey(text))
        .fadeIn(duration: 420.ms, curve: Curves.easeOut)
        .slideY(
          begin: 0.16,
          end: 0,
          duration: 420.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _AnimatedBody extends StatelessWidget {
  const _AnimatedBody(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
        )
        .animate(key: ValueKey(text))
        .fadeIn(delay: 70.ms, duration: 420.ms)
        .slideY(
          begin: 0.14,
          end: 0,
          duration: 420.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _OnboardingBackground extends StatelessWidget {
  const _OnboardingBackground();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF8FAFC), Colors.white],
      ),
    ),
    child: SizedBox.expand(),
  );
}

enum _IllustrationKind { security, network, results }

class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard({required this.kind});
  final _IllustrationKind kind;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      _IllustrationKind.security => 'Biometric face identification scan',
      _IllustrationKind.network => 'Authorized campus Wi-Fi',
      _IllustrationKind.results => 'Election results analytics',
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330, maxHeight: 220),
        child: SizedBox.expand(
          child: DecoratedBox(
            key: ValueKey('onboarding-graphic-${kind.name}'),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8EDF3)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  offset: Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Semantics(
                label: label,
                image: true,
                child: Container(
                  key: kind == _IllustrationKind.security
                      ? const ValueKey('face-scan-illustration')
                      : null,
                  width: 120,
                  height: 120,
                  padding: const EdgeInsets.all(26),
                  decoration: const BoxDecoration(
                    color: _GetStartedScreenState._softBlue,
                    shape: BoxShape.circle,
                  ),
                  child: CustomPaint(painter: _OnboardingIconPainter(kind)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolution-independent outline icons with a consistent 24-unit stroke grid.
class _OnboardingIconPainter extends CustomPainter {
  const _OnboardingIconPainter(this.kind);
  final _IllustrationKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = _GetStartedScreenState._blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (kind) {
      case _IllustrationKind.security:
        final frame = Path()
          ..moveTo(3, 7)
          ..lineTo(3, 3)
          ..lineTo(7, 3)
          ..moveTo(17, 3)
          ..lineTo(21, 3)
          ..lineTo(21, 7)
          ..moveTo(3, 17)
          ..lineTo(3, 21)
          ..lineTo(7, 21)
          ..moveTo(17, 21)
          ..lineTo(21, 21)
          ..lineTo(21, 17);
        canvas.drawPath(frame, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(8, 8)
            ..lineTo(8, 10),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(16, 8)
            ..lineTo(16, 10),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(12, 8)
            ..lineTo(12, 13)
            ..lineTo(10.5, 13),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8, 16)
            ..quadraticBezierTo(12, 20, 16, 16),
          stroke,
        );
      case _IllustrationKind.network:
        for (final radius in [10.0, 6.8, 3.6]) {
          canvas.drawArc(
            Rect.fromCircle(center: const Offset(12, 19), radius: radius),
            math.pi * 1.25,
            math.pi * 0.5,
            false,
            stroke,
          );
        }
        canvas.drawCircle(
          const Offset(12, 19),
          0.8,
          Paint()..color = _GetStartedScreenState._blue,
        );
      case _IllustrationKind.results:
        canvas.drawPath(
          Path()
            ..moveTo(3, 3)
            ..lineTo(3, 21)
            ..lineTo(21, 21),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(6, 15)
            ..lineTo(10, 11)
            ..lineTo(14, 13)
            ..lineTo(21, 5),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(17, 5)
            ..lineTo(21, 5)
            ..lineTo(21, 9),
          stroke,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OnboardingIconPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
