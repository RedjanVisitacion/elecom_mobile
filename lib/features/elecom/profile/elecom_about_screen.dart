import 'package:flutter/material.dart';

import 'elecom_privacy_notice_screen.dart';
import 'elecom_terms_conditions_screen.dart';

class ElecomAboutScreen extends StatelessWidget {
  const ElecomAboutScreen({super.key});

  Widget _sectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.black,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        body,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.35,
              color: Colors.black87,
              fontWeight: FontWeight.w400,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: Colors.black,
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
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black26),
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
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black26),
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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact Support: Coming soon')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
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
