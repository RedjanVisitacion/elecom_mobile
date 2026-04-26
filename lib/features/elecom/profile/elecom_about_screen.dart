import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'elecom_privacy_notice_screen.dart';
import 'elecom_terms_conditions_screen.dart';

class ElecomAboutScreen extends StatelessWidget {
  const ElecomAboutScreen({super.key});

  static final Uri _supportMessengerUri = Uri.parse('https://m.me/redjan.phil.s.visitacion');
  static final Uri _supportEmailUri = Uri(
    scheme: 'mailto',
    path: 'rpsvcodes@gmail.com',
    queryParameters: <String, String>{
      'subject': 'ELECOM Support',
      'body': 'Hello, I need help with my ELECOM account.',
    },
  );

  Future<void> _openMessengerSupport(BuildContext context) async {
    try {
      final launched = await launchUrl(
        _supportMessengerUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;

      final fallback = await launchUrl(
        _supportMessengerUri,
        mode: LaunchMode.platformDefault,
      );
      if (fallback) return;

      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text('Contact Support'),
          content: const Text('Unable to open Messenger. Please open this link:\n\nhttps://m.me/redjan.phil.s.visitacion'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Messenger.')),
      );
    }
  }

  Future<void> _openEmailSupport(BuildContext context) async {
    try {
      final launched = await launchUrl(
        _supportEmailUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;

      final fallback = await launchUrl(
        _supportEmailUri,
        mode: LaunchMode.platformDefault,
      );
      if (fallback) return;

      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text('Contact Support'),
          content: const Text('Unable to open email app. Please email:\n\nrpsvcodes@gmail.com'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app.')),
      );
    }
  }

  Future<void> _contactSupportOptions(BuildContext context) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 10,
            right: 10,
            bottom: MediaQuery.of(ctx).padding.bottom + 10,
          ),
          child: Material(
            color: isDarkMode ? const Color(0xFF2A2A35) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Contact Support',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.facebook, color: Colors.blue),
                  title: Text(
                    'Facebook Messenger',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'Chat with support on Facebook',
                    style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _openMessengerSupport(context);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.email_outlined,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  title: Text(
                    'Email',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'rpsvcodes@gmail.com',
                    style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _openEmailSupport(context);
                  },
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white : Colors.black,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, String body) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A35) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12),
      ),
      child: Text(
        body,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.35,
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w400,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final surface = isDarkMode ? const Color(0xFF171620) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
        title: const Text(
          'About ELECOM',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              children: [
                _sectionHeader(context, 'What is ELECOM?'),
                const SizedBox(height: 10),
                _card(
                  context,
                  'ELECOM in USTP Oroquieta refers to the Electoral Commission of the University of Science and Technology of Southern Philippines – Oroquieta Campus, the official body responsible for managing and supervising student elections within the campus. It oversees the entire election process, including candidate registration, voter verification, election scheduling, monitoring of voting activities, vote counting, and the announcement of official results.',
                ),
                const SizedBox(height: 14),
                _sectionHeader(context, 'About the Voting Platform'),
                const SizedBox(height: 10),
                _card(
                  context,
                  'This mobile application helps students participate in campus elections in a secure and organized way. It provides election details, candidate lists, voting access, and official results once published by ELECOM.',
                ),
                const SizedBox(height: 14),
                _sectionHeader(context, 'Privacy Notice and Terms'),
                const SizedBox(height: 10),
                _card(
                  context,
                  'Please read the Privacy Notice and Terms and Conditions to understand how your data is handled and the rules for using the app.',
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ElecomPrivacyNoticeScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDarkMode ? Colors.white : Colors.black,
                      side: BorderSide(color: isDarkMode ? Colors.white24 : Colors.black26),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text(
                      'Privacy Notice',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ElecomTermsConditionsScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDarkMode ? Colors.white : Colors.black,
                      side: BorderSide(color: isDarkMode ? Colors.white24 : Colors.black26),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text(
                      'Terms and Conditions',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _contactSupportOptions(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? Colors.white : Colors.black,
                  foregroundColor: isDarkMode ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text(
                  'Contact Support',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
