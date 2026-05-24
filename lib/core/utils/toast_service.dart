import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toastification/toastification.dart';

/// Global toast helper for the ELECOM Electoral Commission app.
///
/// Rules enforced here:
///   • Only ONE toast visible at a time — all existing toasts are dismissed
///     before showing a new one.
///   • Duplicate suppression — same message shown within [_dedupeWindow] is
///     silently dropped.
///   • Short auto-dismiss: 2 s (success/info) or 3 s (warning/error).
///   • Login-aware positioning: pass [isLoginScreen: true] to float the toast
///     above the login card instead of below the AppBar.
///   • Navigation helper: call [AppToast.dismissAll()] in route transitions.
///
/// Usage:
///   AppToast.success(context, 'Vote submitted.');
///   AppToast.error(context, 'Login failed (401): Invalid');
///   AppToast.error(context, msg, isLoginScreen: true);   // login screen
///   AppToast.dismissAll();                               // on navigate
abstract final class AppToast {
  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _blue = Color(0xFF2563EB);
  static const Color _gold = Color(0xFFFACC15);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _softRed = Color(0xFFFF6B6B);

  // ── Durations ─────────────────────────────────────────────────────────────
  static const Duration _short = Duration(seconds: 2);
  static const Duration _long = Duration(seconds: 3);
  static const Duration _dedupeWindow = Duration(seconds: 4);

  // ── Shadow ────────────────────────────────────────────────────────────────
  // ── Dedupe state ──────────────────────────────────────────────────────────
  static String? _lastMessage;
  static DateTime? _lastShownAt;

  static bool _isDuplicate(String message) {
    final now = DateTime.now();
    if (_lastMessage == message &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < _dedupeWindow) {
      return true;
    }
    _lastMessage = message;
    _lastShownAt = now;
    return false;
  }

  // ── Margin helpers ────────────────────────────────────────────────────────

  /// Normal screens: float just below the AppBar.
  static EdgeInsets _topMargin(BuildContext context) {
    final statusBar = MediaQuery.of(context).padding.top;
    return EdgeInsets.only(
      top: statusBar + kToolbarHeight + 8,
      left: 14,
      right: 14,
    );
  }

  /// Login screen: float near the top of the safe area so it never covers
  /// the input fields or the login card.
  static EdgeInsets _loginMargin(BuildContext context) {
    final statusBar = MediaQuery.of(context).padding.top;
    return EdgeInsets.only(top: statusBar + 12, left: 14, right: 14);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Dismiss every visible toast immediately (call before navigation).
  static void dismissAll() {
    toastification.dismissAll(delayForAnimation: false);
    _lastMessage = null;
    _lastShownAt = null;
  }

  static void success(
    BuildContext context,
    String message, {
    bool isLoginScreen = false,
  }) {
    _show(
      context,
      message: message,
      type: ToastificationType.success,
      icon: Icons.check_circle_outline_rounded,
      isLoginScreen: isLoginScreen,
      duration: _short,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    bool isLoginScreen = false,
  }) {
    _show(
      context,
      message: message,
      type: ToastificationType.info,
      icon: Icons.info_outline_rounded,
      isLoginScreen: isLoginScreen,
      duration: _short,
    );
  }

  static void warning(
    BuildContext context,
    String message, {
    bool isLoginScreen = false,
  }) {
    _show(
      context,
      message: message,
      type: ToastificationType.warning,
      icon: Icons.warning_amber_rounded,
      isLoginScreen: isLoginScreen,
      duration: _long,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    bool isLoginScreen = false,
  }) {
    _show(
      context,
      message: message,
      type: ToastificationType.error,
      icon: Icons.error_outline_rounded,
      isLoginScreen: isLoginScreen,
      duration: _long,
    );
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static void _show(
    BuildContext context, {
    required String message,
    required ToastificationType type,
    required IconData icon,
    required bool isLoginScreen,
    required Duration duration,
  }) {
    if (_isDuplicate(message)) return;

    // Clear every existing toast before showing the new one.
    toastification.dismissAll(delayForAnimation: false);

    final margin = isLoginScreen ? _loginMargin(context) : _topMargin(context);

    final meta = _ElecomToastMeta.from(type);

    toastification.showCustom(
      context: context,
      autoCloseDuration: duration,
      alignment: Alignment.topCenter,
      dismissDirection: DismissDirection.up,
      animationDuration: const Duration(milliseconds: 360),
      builder: (context, item) {
        return Padding(
          padding: margin,
          child: _ElecomPremiumToast(
            item: item,
            title: meta.title,
            message: message,
            icon: icon,
            accent: meta.accent,
            duration: duration,
          ),
        );
      },
      animationBuilder: (context, animation, alignment, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final slide = Tween<Offset>(
          begin: const Offset(0, -0.26),
          end: Offset.zero,
        ).animate(curve);
        final scale = Tween<double>(begin: 0.96, end: 1).animate(curve);
        return SlideTransition(
          position: slide,
          child: ScaleTransition(
            scale: scale,
            child: FadeTransition(opacity: curve, child: child),
          ),
        );
      },
    );
  }
}

final class _ElecomToastMeta {
  const _ElecomToastMeta({required this.title, required this.accent});

  final String title;
  final Color accent;

  static _ElecomToastMeta from(ToastificationType type) {
    return switch (type) {
      ToastificationType.success => const _ElecomToastMeta(
        title: 'Success',
        accent: AppToast._blue,
      ),
      ToastificationType.error => const _ElecomToastMeta(
        title: 'Unable to continue',
        accent: AppToast._softRed,
      ),
      ToastificationType.warning => const _ElecomToastMeta(
        title: 'Action required',
        accent: AppToast._gold,
      ),
      ToastificationType.info => const _ElecomToastMeta(
        title: 'Notice',
        accent: AppToast._blue,
      ),
    };
  }
}

class _ElecomPremiumToast extends StatefulWidget {
  const _ElecomPremiumToast({
    required this.item,
    required this.title,
    required this.message,
    required this.icon,
    required this.accent,
    required this.duration,
  });

  final ToastificationItem item;
  final String title;
  final String message;
  final IconData icon;
  final Color accent;
  final Duration duration;

  @override
  State<_ElecomPremiumToast> createState() => _ElecomPremiumToastState();
}

class _ElecomPremiumToastState extends State<_ElecomPremiumToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width - 28, 350.0);

    return Center(
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            splashColor: widget.accent.withValues(alpha: 0.08),
            highlightColor: widget.accent.withValues(alpha: 0.05),
            onTap: () => toastification.dismiss(widget.item),
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: width,
                  decoration: BoxDecoration(
                    color: AppToast._dark.withValues(alpha: 0.84),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: widget.accent.withValues(alpha: 0.30),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.13),
                        AppToast._dark.withValues(alpha: 0.82),
                        Colors.black.withValues(alpha: 0.78),
                      ],
                      stops: const [0, 0.46, 1],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.34),
                        blurRadius: 26,
                        offset: const Offset(0, 14),
                      ),
                      BoxShadow(
                        color: widget.accent.withValues(alpha: 0.20),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ElecomToastGlowPainter(widget.accent),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ElecomToastIcon(
                              icon: widget.icon,
                              accent: widget.accent,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.7,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.message,
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFCBD5E1),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12.3,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, _) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: 1 - _progressController.value,
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        widget.accent.withValues(alpha: 0.10),
                                        widget.accent.withValues(alpha: 0.72),
                                        Colors.white.withValues(alpha: 0.50),
                                      ],
                                    ),
                                  ),
                                ),
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
      ),
    );
  }
}

class _ElecomToastIcon extends StatelessWidget {
  const _ElecomToastIcon({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.88, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: 0.13),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.24), blurRadius: 16),
          ],
        ),
        child: Icon(icon, color: accent, size: 19),
      ),
    );
  }
}

class _ElecomToastGlowPainter extends CustomPainter {
  const _ElecomToastGlowPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.10, size.height * 0.18),
        size.width * 0.58,
        [accent.withValues(alpha: 0.16), Colors.transparent],
      );
    canvas.drawRect(Offset.zero & size, glow);

    final line = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, 0),
        [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.26),
          accent.withValues(alpha: 0.20),
          Colors.white.withValues(alpha: 0),
        ],
        const [0, 0.35, 0.65, 1],
      )
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(18, 0.5), Offset(size.width - 18, 0.5), line);
  }

  @override
  bool shouldRepaint(covariant _ElecomToastGlowPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}
