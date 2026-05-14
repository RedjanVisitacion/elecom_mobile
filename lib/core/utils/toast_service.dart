import 'package:flutter/material.dart';
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
  static const Color _bg = Colors.white;
  static const Color _fg = Color(0xFF0D0D0D);
  static const Color _iconColor = Color(0xFF1C1C1E);
  static const Color _borderColor = Color(0xFFE5E5E5);

  // ── Durations ─────────────────────────────────────────────────────────────
  static const Duration _short = Duration(seconds: 2);
  static const Duration _long = Duration(seconds: 3);
  static const Duration _dedupeWindow = Duration(seconds: 4);

  // ── Shadow ────────────────────────────────────────────────────────────────
  static const List<BoxShadow> _shadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 16,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 4,
      spreadRadius: 0,
      offset: Offset(0, 1),
    ),
  ];

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
    return EdgeInsets.only(
      top: statusBar + 12,
      left: 14,
      right: 14,
    );
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

    final margin = isLoginScreen
        ? _loginMargin(context)
        : _topMargin(context);

    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.flat,
      title: Text(
        message,
        style: const TextStyle(
          color: _fg,
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
          height: 1.4,
        ),
      ),
      icon: Icon(icon, color: _iconColor, size: 20),
      backgroundColor: _bg,
      foregroundColor: _fg,
      borderSide: const BorderSide(color: _borderColor, width: 1),
      borderRadius: BorderRadius.circular(14),
      boxShadow: _shadow,
      showProgressBar: false,
      closeButtonShowType: CloseButtonShowType.none,
      autoCloseDuration: duration,
      alignment: Alignment.topCenter,
      margin: margin,
      animationDuration: const Duration(milliseconds: 220),
      animationBuilder: (context, animation, alignment, child) {
        final slide = Tween<Offset>(
          begin: const Offset(0, -0.4),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));
        return SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
