import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/notifications/notification_center_store.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../elecom/presentation/elecom_dashboard.dart';
import '../../../core/session/session_persistence.dart';
import '../../../screens/get_started_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  Future<void>? _flow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flow ??= _runFlow();
    });
  }

  Future<void> _runFlow() async {
    final startedAt = DateTime.now();

    try {
      await Future.wait<void>([
        precacheImage(
          const AssetImage('assets/no_txt_no_bg_elecom.png'),
          context,
        ),
        precacheImage(
          const AssetImage('assets/img_text/elecom_black1.png'),
          context,
        ),
      ]);
    } catch (_) {
      // ignore
    }

    final elapsed = DateTime.now().difference(startedAt);
    const minDuration = Duration(milliseconds: 1100);
    if (elapsed < minDuration) {
      await Future<void>.delayed(minDuration - elapsed);
    }

    final hasSession = await SessionPersistence.restore();
    if (hasSession) {
      await NotificationCenterStore.init(forceRefresh: true);
      await PushNotificationService.syncForLoggedInUser();
    }

    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (!hasSession && await GetStartedScreen.shouldShow()) {
      if (!navigator.mounted) return;
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const GetStartedScreen()),
      );
      return;
    }

    if (!navigator.mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            hasSession ? const ElecomDashboard() : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Stack(
            children: [
              Center(
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/no_txt_no_bg_elecom.png',
                        width: 160,
                        height: 160,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                      const SizedBox(height: 18),
                      const _FiveDotsLoader(),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Opacity(
                    opacity: 0.85,
                    child: Image.asset(
                      'assets/img_text/elecom_black1.png',
                      height: 26,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FiveDotsLoader extends StatefulWidget {
  const _FiveDotsLoader();

  @override
  State<_FiveDotsLoader> createState() => _FiveDotsLoaderState();
}

class _FiveDotsLoaderState extends State<_FiveDotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final phase = (t + (i * 0.12)) % 1.0;
            final bump = (1.0 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
            final scale = 0.75 + (bump * 0.55);
            final opacity = 0.25 + (bump * 0.75);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
