import 'package:flutter/material.dart';

import '../../../core/session/notification_preferences.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _pushNotifications = true;
  bool _inAppNotifications = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final push = await NotificationPreferences.isPushEnabled();
    final inApp = await NotificationPreferences.isInAppEnabled();
    if (!mounted) return;
    setState(() {
      _pushNotifications = push;
      _inAppNotifications = inApp;
      _loading = false;
    });
  }

  Future<void> _setPushNotifications(bool value) async {
    setState(() {
      _pushNotifications = value;
    });
    await NotificationPreferences.setPushEnabled(value);
  }

  Future<void> _setInAppNotifications(bool value) async {
    setState(() {
      _inAppNotifications = value;
    });
    await NotificationPreferences.setInAppEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final sectionIconBg = isDarkMode ? const Color(0xFF2F3240) : const Color(0xFFF1F4FA);
    final dividerColor = isDarkMode ? Colors.white12 : const Color(0xFFE5E7EB);
    final titleColor = isDarkMode ? Colors.white : const Color(0xFF111827);
    final iconColor = isDarkMode ? Colors.white70 : const Color(0xFF6CA3E5);
    final switchTrackColor = isDarkMode ? const Color(0xFF5A7BCF) : const Color(0xFF9CC2F3);
    final switchThumbColor = isDarkMode ? const Color(0xFF7EB6FF) : const Color(0xFF3B82F6);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notification Settings',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: titleColor,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                children: [
                  _NotificationRow(
                    icon: Icons.phone_iphone_outlined,
                    label: 'Push Notifications',
                    value: _pushNotifications,
                    onChanged: _setPushNotifications,
                    titleColor: titleColor,
                    iconColor: iconColor,
                    iconBackgroundColor: sectionIconBg,
                    switchTrackColor: switchTrackColor,
                    switchThumbColor: switchThumbColor,
                  ),
                  Divider(color: dividerColor, height: 22),
                  _NotificationRow(
                    icon: Icons.mail_outline,
                    label: 'In-app Notifications',
                    value: _inAppNotifications,
                    onChanged: _setInAppNotifications,
                    titleColor: titleColor,
                    iconColor: iconColor,
                    iconBackgroundColor: sectionIconBg,
                    switchTrackColor: switchTrackColor,
                    switchThumbColor: switchThumbColor,
                  ),
                  Divider(color: dividerColor, height: 22),
                ],
              ),
            ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.titleColor,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.switchTrackColor,
    required this.switchThumbColor,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color titleColor;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Color switchTrackColor;
  final Color switchThumbColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconBackgroundColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 31 / 2,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: switchTrackColor,
          activeColor: switchThumbColor,
        ),
      ],
    );
  }
}
