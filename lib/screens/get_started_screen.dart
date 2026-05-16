import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:introduction_screen/introduction_screen.dart';
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
  int _currentPage = 0;
  bool _isCompleting = false;

  static const _black = Color(0xFF050505);
  static const _blue = Color(0xFF135FCF);
  static const _yellow = Color(0xFFFFC928);
  static const _softBlue = Color(0xFFEAF4FF);
  static const _softYellow = Color(0xFFFFF6D8);
  static const _text = Color(0xFF101010);

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    await GetStartedScreen.markComplete();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages(context);

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
            IntroductionScreen(
              pages: pages,
              onDone: _completeOnboarding,
              onSkip: _completeOnboarding,
              onChange: (index) => setState(() => _currentPage = index),
              showSkipButton: true,
              skip: const Text('Skip'),
              next: const Text('Next'),
              done: Text(_isCompleting ? 'Opening...' : 'Continue to Login'),
              curve: Curves.easeOutCubic,
              animationDuration: 480,
              globalBackgroundColor: Colors.transparent,
              isProgressTap: true,
              customProgress: AnimatedSmoothIndicator(
                activeIndex: _currentPage,
                count: pages.length,
                effect: const ExpandingDotsEffect(
                  dotHeight: 8,
                  dotWidth: 8,
                  expansionFactor: 3.1,
                  spacing: 7,
                  activeDotColor: _black,
                  dotColor: Color(0xFFE0E0E0),
                ),
              ),
              baseBtnStyle: TextButton.styleFrom(
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              skipStyle: TextButton.styleFrom(foregroundColor: _black),
              nextStyle: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _black,
                shadowColor: _black.withValues(alpha: 0.22),
                elevation: 5,
              ),
              doneStyle: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _black,
                shadowColor: _black.withValues(alpha: 0.24),
                elevation: 6,
              ),
              dotsContainerDecorator: const ShapeDecoration(
                color: Colors.transparent,
                shape: StadiumBorder(),
              ),
              controlsMargin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            ),
          ],
        ),
      ),
    );
  }

  List<PageViewModel> _pages(BuildContext context) {
    return const [
      _OnboardingData(
        title: 'Welcome to ELECOM',
        description:
            'Modernizing Campus Elections at USTP Oroquieta through secure and digital voting technology.',
        kind: _IllustrationKind.students,
      ),
      _OnboardingData(
        title: 'Secure & Transparent Voting',
        description:
            'Your votes are protected with secure digital safeguards and transparent election records.',
        kind: _IllustrationKind.security,
      ),
      _OnboardingData(
        title: 'Vote Anywhere on Campus',
        description:
            'Access elections easily using your mobile device through authorized campus networks.',
        kind: _IllustrationKind.network,
      ),
      _OnboardingData(
        title: 'Fast & Accurate Results',
        description:
            'Automated vote counting ensures quick, reliable, and transparent election results.',
        kind: _IllustrationKind.results,
      ),
      _OnboardingData(
        title: 'Ready to Get Started?',
        description: 'Experience a smarter and more secure campus election system.',
        kind: _IllustrationKind.ready,
      ),
    ].map(_buildPage).toList(growable: false);
  }

  PageViewModel _buildPage(_OnboardingData data) {
    return PageViewModel(
      titleWidget: _AnimatedTitle(data.title),
      bodyWidget: _AnimatedBody(data.description),
      image: _IllustrationCard(kind: data.kind),
      decoration: const PageDecoration(
        pageColor: Colors.transparent,
        imageFlex: 5,
        bodyFlex: 4,
        imagePadding: EdgeInsets.fromLTRB(24, 26, 24, 8),
        contentMargin: EdgeInsets.symmetric(horizontal: 28),
        titlePadding: EdgeInsets.only(top: 10, bottom: 14),
        bodyPadding: EdgeInsets.symmetric(horizontal: 4),
        safeArea: 96,
      ),
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
            fontSize: 28,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        )
        .animate(key: ValueKey(text))
        .fadeIn(duration: 420.ms, curve: Curves.easeOut)
        .slideY(begin: 0.16, end: 0, duration: 420.ms, curve: Curves.easeOutCubic);
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
              color: Color(0xFF4F4F4F),
              fontSize: 15.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        )
        .animate(key: ValueKey(text))
        .fadeIn(delay: 70.ms, duration: 420.ms)
        .slideY(begin: 0.14, end: 0, duration: 420.ms, curve: Curves.easeOutCubic);
  }
}

class _OnboardingBackground extends StatelessWidget {
  const _OnboardingBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFFBEB),
            Color(0xFFFFFFFF),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _GridPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard({required this.kind});

  final _IllustrationKind kind;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth.clamp(230.0, 330.0);
        return Center(
          child: SizedBox(
            width: size,
            height: size * 0.9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE6E6E6)),
                boxShadow: [
                  BoxShadow(
                    color: _GetStartedScreenState._black.withValues(alpha: 0.10),
                    blurRadius: 32,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _Scene(kind: kind),
              ),
            )
                .animate(key: ValueKey(kind))
                .fadeIn(duration: 460.ms)
                .slideY(begin: -0.04, end: 0, duration: 460.ms, curve: Curves.easeOutCubic)
                .then()
                .moveY(
                  begin: -4,
                  end: 5,
                  duration: 1800.ms,
                  curve: Curves.easeInOut,
                )
                .then()
                .moveY(
                  begin: 5,
                  end: -4,
                  duration: 1800.ms,
                  curve: Curves.easeInOut,
                ),
          ),
        );
      },
    );
  }
}

enum _IllustrationKind { students, security, network, results, ready }

class _Scene extends StatelessWidget {
  const _Scene({required this.kind});

  final _IllustrationKind kind;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _NetworkPainter(kind: kind)),
        ),
        if (kind == _IllustrationKind.students) ...[
          const Positioned(top: 20, left: 18, child: _CampusBadge()),
          const Positioned(bottom: 18, left: 18, child: _StudentAvatar()),
          const Positioned(bottom: 18, right: 18, child: _StudentAvatar(isAlt: true)),
          const _PhoneMockup(icon: Icons.how_to_vote_rounded),
        ],
        if (kind == _IllustrationKind.security) ...[
          const Positioned(top: 24, right: 20, child: _NodeCluster()),
          const _ShieldBallot(),
        ],
        if (kind == _IllustrationKind.network) ...[
          const Positioned(top: 18, child: _CampusBadge(wide: true)),
          const Positioned(bottom: 18, child: _WifiBands()),
          const _PhoneMockup(icon: Icons.wifi_tethering_rounded),
        ],
        if (kind == _IllustrationKind.results) ...[
          const _DashboardMockup(),
          Positioned(
            right: 22,
            top: 26,
            child: _CircleIcon(icon: Icons.analytics_rounded),
          ),
        ],
        if (kind == _IllustrationKind.ready) ...[
          const Positioned(top: 18, child: _CircleIcon(icon: Icons.verified_user_rounded, large: true)),
          const Positioned(bottom: 20, child: _PhoneMockup(icon: Icons.login_rounded)),
        ],
      ],
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  const _PhoneMockup({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 102,
      height: 162,
      decoration: BoxDecoration(
        color: _GetStartedScreenState._black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33050505),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _GetStartedScreenState._blue, size: 36),
              const SizedBox(height: 12),
              const _MiniLine(width: 48),
              const SizedBox(height: 7),
              const _MiniLine(width: 34),
              const SizedBox(height: 16),
              Container(
                width: 54,
                height: 18,
                decoration: BoxDecoration(
                  color: _GetStartedScreenState._black,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShieldBallot extends StatelessWidget {
  const _ShieldBallot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 138,
      height: 150,
      decoration: BoxDecoration(
        color: _GetStartedScreenState._softYellow,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.shield_rounded,
            size: 112,
            color: _GetStartedScreenState._black.withValues(alpha: 0.95),
          ),
          const Positioned(
            top: 48,
            child: Icon(
              Icons.how_to_vote_rounded,
              color: _GetStartedScreenState._yellow,
              size: 42,
            ),
          ),
          const Positioned(
            bottom: 38,
            child: Icon(
              Icons.check_circle_rounded,
              color: _GetStartedScreenState._yellow,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMockup extends StatelessWidget {
  const _DashboardMockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 178,
      height: 128,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A050505),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: const [
          _Bar(height: 46),
          _Bar(height: 72),
          _Bar(height: 34),
          _Bar(height: 90),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: _GetStartedScreenState._black,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentAvatar extends StatelessWidget {
  const _StudentAvatar({this.isAlt = false});

  final bool isAlt;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: isAlt
              ? _GetStartedScreenState._yellow
              : _GetStartedScreenState._blue,
          child: Icon(Icons.person_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 5),
        Container(
          width: 46,
          height: 18,
          decoration: BoxDecoration(
            color: isAlt
                ? _GetStartedScreenState._yellow.withValues(alpha: 0.55)
                : _GetStartedScreenState._blue.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}

class _CampusBadge extends StatelessWidget {
  const _CampusBadge({this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? 150 : 104,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _GetStartedScreenState._softYellow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.account_balance_rounded,
            color: _GetStartedScreenState._black,
          ),
          if (wide) ...[
            const SizedBox(width: 8),
            const Flexible(child: _MiniLine(width: 70)),
          ],
        ],
      ),
    );
  }
}

class _NodeCluster extends StatelessWidget {
  const _NodeCluster();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 66,
      child: CustomPaint(painter: _NodePainter()),
    );
  }
}

class _WifiBands extends StatelessWidget {
  const _WifiBands();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.wifi_rounded,
      color: _GetStartedScreenState._black,
      size: 72,
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, this.large = false});

  final IconData icon;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: large ? 92 : 58,
      height: large ? 92 : 58,
      decoration: BoxDecoration(
        color: _GetStartedScreenState._softBlue,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Icon(
        icon,
        color: _GetStartedScreenState._black,
        size: large ? 44 : 30,
      ),
    );
  }
}

class _MiniLine extends StatelessWidget {
  const _MiniLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 7,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF1F1F1)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NetworkPainter extends CustomPainter {
  const _NetworkPainter({required this.kind});

  final _IllustrationKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = _GetStartedScreenState._blue.withValues(alpha: 0.13)
      ..strokeWidth = 2;
    final dotPaint = Paint()
      ..color = _GetStartedScreenState._yellow.withValues(alpha: 0.55);

    final points = <Offset>[
      Offset(size.width * 0.16, size.height * 0.22),
      Offset(size.width * 0.76, size.height * 0.18),
      Offset(size.width * 0.86, size.height * 0.62),
      Offset(size.width * 0.22, size.height * 0.76),
      Offset(size.width * 0.50, size.height * 0.42),
    ];

    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], kind == _IllustrationKind.ready ? 5 : 6, dotPaint);
      if (i < points.length - 1) {
        canvas.drawLine(points[i], points[i + 1], linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkPainter oldDelegate) {
    return oldDelegate.kind != kind;
  }
}

class _NodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(size.width * 0.18, size.height * 0.2),
      Offset(size.width * 0.76, size.height * 0.24),
      Offset(size.width * 0.52, size.height * 0.78),
    ];
    final line = Paint()
      ..color = _GetStartedScreenState._blue.withValues(alpha: 0.25)
      ..strokeWidth = 2;
    final dot = Paint()..color = _GetStartedScreenState._black;

    canvas.drawLine(points[0], points[1], line);
    canvas.drawLine(points[1], points[2], line);
    canvas.drawLine(points[2], points[0], line);
    for (final point in points) {
      canvas.drawCircle(point, 8, dot);
      canvas.drawCircle(
        point,
        14,
        Paint()..color = _GetStartedScreenState._yellow.withValues(alpha: 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
