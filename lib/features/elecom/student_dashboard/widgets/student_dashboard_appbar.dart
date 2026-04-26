import 'dart:ui';

import 'package:flutter/material.dart';

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
                  Text('• Cast only one vote per election using your own verified account.'),
                  Text('• Not tamper with, automate, or interfere with the voting process.'),
                  Text('• Respect the rules set by ELECOM and your institution.'),
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
    String? titleText,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      title: titleText != null
          ? Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                titleText,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
              ),
            )
          : isElecom
              ? Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Opacity(
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
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon')),
            );
          },
          icon: const Icon(Icons.notifications_none),
        ),
      ],
    );
  }
}
