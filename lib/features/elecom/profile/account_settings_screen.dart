import 'package:flutter/material.dart';

import 'personal_information_screen.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;
    final dividerColor = isDarkMode ? Colors.white12 : const Color(0xFFE5E7EB);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Account Settings',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: titleColor,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Account',
                style: TextStyle(
                  fontSize: 34 / 2,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            title: Text(
              'Personal Information',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            subtitle: Text(
              'View and edit your profile',
              style: TextStyle(color: subtitleColor),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PersonalInformationScreen()),
              );
            },
          ),
          Divider(color: dividerColor),
        ],
      ),
    );
  }
}
