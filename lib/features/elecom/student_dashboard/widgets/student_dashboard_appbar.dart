import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/session/user_session.dart';
import '../../../auth/presentation/login_screen.dart';
import '../../profile/profile_screen.dart';

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
  }) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      title: isElecom
          ? Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Opacity(
                opacity: 0.85,
                child: Image.asset(
                  'assets/img_text/elecom_black1.png',
                  height: 24,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Text('ELECOM'),
                ),
              ),
            )
          : const Text('Dashboard'),
      actions: [
        PopupMenuButton<_MenuAction>(
          tooltip: 'Menu',
          icon: const Icon(Icons.more_vert),
          position: PopupMenuPosition.under,
          offset: const Offset(0, 8),
          color: Colors.white,
          surfaceTintColor: Colors.white,
          itemBuilder: (context) {
            final name = (UserSession.fullName ?? '').trim();
            final displayName = name.isNotEmpty ? name : (UserSession.studentId ?? '');
            final parts = displayName.split(RegExp(r'\s+')).where((p) => p.trim().isNotEmpty).toList();
            final shortName = parts.length >= 2 ? '${parts.first} ${parts.last}' : displayName;

            return [
              PopupMenuItem<_MenuAction>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(0xFFEAEAEA),
                          child: Icon(Icons.person, size: 18, color: Colors.black87),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            shortName.isEmpty ? 'User' : shortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<_MenuAction>(
                value: _MenuAction.profile,
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 10),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<_MenuAction>(
                value: _MenuAction.logout,
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ];
          },
          onSelected: (action) {
            if (action == _MenuAction.profile) {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
              return;
            }

            if (action == _MenuAction.logout) {
              ApiClient.clearSession();
              UserSession.clear();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
          },
        ),
      ],
    );
  }
}

enum _MenuAction { profile, logout }
