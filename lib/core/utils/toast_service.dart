import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// Global toast helper for the ELECOM Electoral Commission app.
///
/// Design: clean black-and-white minimalist.
///   - White background, black text and icons on all toast types.
///   - Success / Info  → top of screen, BELOW the AppBar.
///   - Warning / Error → bottom of screen, above gesture bar.
///
/// Usage:
///   AppToast.success(context, 'Vote submitted successfully.');
///   AppToast.info(context, 'Voting has started.');
///   AppToast.warning(context, 'Election is not active.');
///   AppToast.error(context, 'Face verification failed.');
abstract final class AppToast {
  // ── Shared palette ────────────────────────────────────────────────────────
  static const Color _bg = Colors.white;
  static const Color _fg = Color(0xFF0D0D0D);
  static const Color _iconColor = Color(0xFF1C1C1E);
  static const Color _borderColor = Color(0xFFE5E5E5);

  // ── Durations ─────────────────────────────────────────────────────────────
  static const Duration _short = Duration(seconds: 3);
  static const Duration _long = Duration(milliseconds: 3500);

  // ── Shared shadow ─────────────────────────────────────────────────────────
  static const List<BoxShadow> _shadow = [
    BoxShadow(
      color: Color(0x18000000),
      blurRadius: 20,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 6,
      spreadRadius: 0,
      offset: Offset(0, 1),
    ),
  ];

  // ── Top margin: computed below the status bar + AppBar ───────────────────
  /// Clears the status bar + standard AppBar (kToolbarHeight = 56 dp) plus
  /// 8 dp breathing room so the toast floats visibly below the header.
  static EdgeInsets _topMargin(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    const gap = 8.0;
    final top = statusBarHeight + kToolbarHeight + gap;
    return EdgeInsets.only(top: top, left: 14, right: 14);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Top (below AppBar) — operation completed successfully.
  static void success(BuildContext context, String message) {
    _show(
      context,
      message: message,
      type: ToastificationType.success,
      icon: Icons.check_circle_outline_rounded,
      margin: _topMargin(context),
      duration: _short,
    );
  }

  /// Top (below AppBar) — neutral informational update.
  static void info(BuildContext context, String message) {
    _show(
      context,
      message: message,
      type: ToastificationType.info,
      icon: Icons.info_outline_rounded,
      margin: _topMargin(context),
      duration: _short,
    );
  }

  /// Top (below AppBar) — caution or validation message.
  static void warning(BuildContext context, String message) {
    _show(
      context,
      message: message,
      type: ToastificationType.warning,
      icon: Icons.warning_amber_rounded,
      margin: _topMargin(context),
      duration: _long,
    );
  }

  /// Top (below AppBar) — something went wrong.
  static void error(BuildContext context, String message) {
    _show(
      context,
      message: message,
      type: ToastificationType.error,
      icon: Icons.error_outline_rounded,
      margin: _topMargin(context),
      duration: _long,
    );
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static void _show(
    BuildContext context, {
    required String message,
    required ToastificationType type,
    required IconData icon,
    required EdgeInsets margin,
    required Duration duration,
  }) {
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
      animationDuration: const Duration(milliseconds: 280),
      animationBuilder: (context, animation, alignment, child) {
        final slide = Tween<Offset>(
          begin: const Offset(0, -0.5),
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
