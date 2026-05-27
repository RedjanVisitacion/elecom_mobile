import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/notifications/notification_center_store.dart';
import '../../profile/notifications_screen.dart';

class StudentDashboardAppBar {
  static void showElecomTermsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text('ELECOM Voting Terms & Conditions'),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('By participating in elections, you agree to:'),
                  SizedBox(height: 8),
                  Text(
                    '• Cast only one vote per election using your own verified account.',
                  ),
                  Text(
                    '• Not tamper with, automate, or interfere with the voting process.',
                  ),
                  Text(
                    '• Respect the rules set by ELECOM and your institution.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                child: const Text('CLOSE'),
              ),
            ],
          ),
        );
      },
    );
  }

  static PreferredSizeWidget build({
    required BuildContext context,
    required bool isElecom,
    bool isPremiumMode = false,
    bool forceDarkMode = false,
    String? titleText,
  }) {
    final isDarkMode =
        forceDarkMode || Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    NotificationCenterStore.init();

    return AppBar(
      elevation: 0,
      backgroundColor: isPremiumMode ? Colors.transparent : null,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 0,
      title: titleText != null
          ? Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                titleText,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
            )
          : isElecom
          ? Padding(
              padding: const EdgeInsets.only(left: 12),
              child: isPremiumMode
                  ? const _PremiumCommissionTitle()
                  : Opacity(
                      opacity: 0.85,
                      child: Image.asset(
                        isDarkMode
                            ? 'assets/img_text/elecom_white1.png'
                            : 'assets/img_text/elecom_black1.png',
                        height: 24,
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => const Text('ELECOM'),
                      ),
                    ),
            )
          : const Text('Dashboard'),
      actions: [
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
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const NotificationsScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) =>
                            child,
                    opaque: true,
                    barrierColor: null,
                    barrierDismissible: false,
                    barrierLabel: null,
                    maintainState: true,
                    fullscreenDialog: false,
                  ),
                );
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: isPremiumMode ? 38 : null,
                    height: isPremiumMode ? 38 : null,
                    alignment: Alignment.center,
                    decoration: isPremiumMode
                        ? BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.56),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF2563EB,
                                ).withValues(alpha: 0.18),
                                blurRadius: 16,
                              ),
                            ],
                          )
                        : null,
                    child: Icon(
                      isPremiumMode
                          ? Iconsax.notification_bing
                          : Icons.notifications_none,
                      color: isPremiumMode
                          ? const Color(0xFFFACC15)
                          : titleColor,
                      size: isPremiumMode ? 22 : 24,
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 1,
                      top: 1,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isPremiumMode ? 4 : 5,
                          vertical: isPremiumMode ? 1 : 2,
                        ),
                        constraints: BoxConstraints(
                          minWidth: isPremiumMode ? 15 : 16,
                          minHeight: isPremiumMode ? 15 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: isPremiumMode
                              ? const Color(0xFFEF4444)
                              : Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: isPremiumMode
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFEF4444,
                                    ).withValues(alpha: 0.32),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
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
    );
  }
}

class _PremiumCommissionTitle extends StatefulWidget {
  const _PremiumCommissionTitle();

  @override
  State<_PremiumCommissionTitle> createState() =>
      _PremiumCommissionTitleState();
}

class _PremiumCommissionTitleState extends State<_PremiumCommissionTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
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
      builder: (context, child) {
        final sweep = _controller.value * 2.2 - 0.65;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            Positioned(
              left: -8,
              right: -16,
              child: IgnorePointer(
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.14),
                        blurRadius: 18,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFACC15).withValues(alpha: 0.10),
                        blurRadius: 16,
                        offset: const Offset(10, 0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: const [
                    Color(0xFF0F172A),
                    Color(0xFF0F172A),
                    Color(0xFF2563EB),
                    Color(0xFFFACC15),
                    Color(0xFF0F172A),
                    Color(0xFF0F172A),
                  ],
                  stops: [
                    0,
                    (sweep - 0.18).clamp(0.0, 1.0),
                    (sweep - 0.05).clamp(0.0, 1.0),
                    sweep.clamp(0.0, 1.0),
                    (sweep + 0.14).clamp(0.0, 1.0),
                    1,
                  ],
                ).createShader(bounds);
              },
              child: Image.asset(
                'assets/img_text/elecom_black1.png',
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const Text(
                  'Electoral Commission',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
