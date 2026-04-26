import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ElecomFaqsScreen extends StatelessWidget {
  const ElecomFaqsScreen({super.key});

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
            color: Colors.white,
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
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Contact Support',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.facebook, color: Colors.blue),
                  title: const Text('Facebook Messenger', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Chat with support on Facebook'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _openMessengerSupport(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: Colors.black87),
                  title: const Text('Email', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('rpsvcodes@gmail.com'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _openEmailSupport(context);
                  },
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(foregroundColor: Colors.black54),
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

  @override
  Widget build(BuildContext context) {
    const primary = Colors.black;
    const surface = Color(0xFFF5F5F5);

    final faqs = <({String title, String body})>[
      (
        title: 'What is ELECOM (USTP Oroquieta)?',
        body:
            'ELECOM in USTP Oroquieta refers to the Electoral Commission of the University of Science and Technology of Southern Philippines – Oroquieta Campus, the official body responsible for managing and supervising student elections within the campus. It oversees the entire election process, including candidate registration, voter verification, election scheduling, monitoring of voting activities, vote counting, and the announcement of official results. Its primary role is to ensure that all campus elections are conducted in a fair, secure, transparent, and well-organized manner.',
      ),
      (
        title: 'How do I vote?',
        body:
            '1) Log in using your verified student account.\n2) Open the Election tab to see active elections.\n3) Select your candidate(s) and confirm your vote.\n4) Save or view your receipt after voting (if available).',
      ),
      (
        title: 'Why can\'t I log in?',
        body:
            'Make sure your Student ID and password are correct. If you forgot your password or your account is not yet verified, contact your ELECOM administrator or campus IT support.',
      ),
      (
        title: 'Can I change my vote after submitting?',
        body:
            'No. Once your vote is submitted, it becomes final to protect election integrity. Please review your selections carefully before confirming.',
      ),
      (
        title: 'How do I update my profile photo?',
        body:
            'Go to the Profile section and tap your photo to choose a new image. Once uploaded, it will reflect on your account after syncing.',
      ),
      (
        title: 'When will results be announced?',
        body:
            'Results are published by ELECOM after vote counting and verification. Check the Results tab for official announcements.',
      ),
    ];

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Help Center',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Frequently Asked',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...faqs.map(
                  (f) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        iconColor: primary,
                        collapsedIconColor: primary,
                        title: Text(
                          f.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              f.body,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    height: 1.35,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w400,
                                  ),
                            ),
                          ),
                        ],
                      ),
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
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
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
