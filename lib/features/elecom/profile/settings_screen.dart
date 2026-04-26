import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'account_settings_screen.dart';
import 'notification_settings_screen.dart';
import '../student_dashboard/utils/theme_notifier.dart';
import 'elecom_privacy_notice_screen.dart';
import 'elecom_terms_conditions_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String _appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          _SectionTitle(
            title: 'APPEARANCE',
            accentColor: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 6),
          _SettingsTile(
            title: 'Dark mode',
            subtitle: 'Light mode, dark mode, or follow system setting',
            onTap: () => _showThemeModeSelector(context),
          ),
          const SizedBox(height: 18),
          _SectionTitle(
            title: 'PRIVACY AND SECURITY',
            accentColor: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 6),
          _SettingsTile(
            title: 'Notification Settings',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),
          _SettingsTile(
            title: 'Account Settings',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
              );
            },
          ),
          _SettingsTile(
            title: 'Change Password',
            onTap: () => _showComingSoon(context, 'Change Password'),
          ),
          const SizedBox(height: 18),
          _SectionTitle(
            title: 'ABOUT Elecom',
            accentColor: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 6),
          _SettingsTile(
            title: 'Terms and Conditions',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ElecomTermsConditionsScreen()),
              );
            },
          ),
          _SettingsTile(
            title: 'Privacy Notice',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ElecomPrivacyNoticeScreen()),
              );
            },
          ),
          _SettingsTile(
            title: 'App Version',
            trailingText: _appVersion,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Future<void> _showThemeModeSelector(BuildContext context) async {
    final notifier = context.read<ThemeNotifier>();
    final currentMode = notifier.themeMode;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDarkMode ? const Color(0xFF2A2A35) : Colors.white;
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(left: 10, right: 10, bottom: safeBottom + 10),
          child: Material(
            color: sheetColor,
            surfaceTintColor: sheetColor,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white24 : Theme.of(ctx).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        'Choose appearance',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ThemeModeTile(
                      title: 'Light mode',
                      value: ThemeMode.light,
                      groupValue: currentMode,
                      onChanged: (mode) => _applyTheme(ctx, mode),
                    ),
                    _ThemeModeTile(
                      title: 'Dark mode',
                      value: ThemeMode.dark,
                      groupValue: currentMode,
                      onChanged: (mode) => _applyTheme(ctx, mode),
                    ),
                    _ThemeModeTile(
                      title: 'System default',
                      subtitle: 'Follows your phone appearance setting',
                      value: ThemeMode.system,
                      groupValue: currentMode,
                      onChanged: (mode) => _applyTheme(ctx, mode),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _applyTheme(BuildContext context, ThemeMode? mode) {
    if (mode == null) return;
    context.read<ThemeNotifier>().setThemeMode(mode);
    Navigator.of(context).pop();
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.accentColor,
  });

  final String title;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingText,
  });

  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDarkMode ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
      trailing: trailingText != null
          ? Text(
              trailingText!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          : Icon(
              Icons.chevron_right,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
      onTap: onTap,
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final ThemeMode value;
  final ThemeMode groupValue;
  final ValueChanged<ThemeMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return RadioListTile<ThemeMode>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
            ),
      fillColor: WidgetStatePropertyAll<Color>(
        isDarkMode ? Colors.white70 : Colors.black,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
