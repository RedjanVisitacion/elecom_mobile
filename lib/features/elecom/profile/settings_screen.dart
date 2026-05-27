import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../../services/tutorial_service.dart';
import 'account_settings_screen.dart';
import 'change_password_screen.dart';
import 'notification_settings_screen.dart';
import '../student_dashboard/utils/theme_notifier.dart';
import 'elecom_privacy_notice_screen.dart';
import 'elecom_terms_conditions_screen.dart';

const _premiumBlue = Color(0xFF2563EB);
const _premiumGold = Color(0xFFFACC15);
const _premiumInk = Color(0xFF0F172A);
const _premiumSub = Color(0xFF475569);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String _appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appearance = context.watch<ThemeNotifier>().appearance;
    final isPremiumMode = appearance == AppAppearance.premium;
    final pageBg = isPremiumMode
        ? Colors.white
        : isDarkMode
        ? const Color(0xFF171620)
        : Colors.white;
    final titleColor = isPremiumMode
        ? _premiumInk
        : isDarkMode
        ? Colors.white
        : Colors.black;
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: isPremiumMode ? Colors.white : Colors.transparent,
        surfaceTintColor: isPremiumMode ? Colors.white : Colors.transparent,
        foregroundColor: titleColor,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900, color: titleColor),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isPremiumMode
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    _premiumBlue.withValues(alpha: 0.08),
                    _premiumGold.withValues(alpha: 0.06),
                    Colors.white,
                  ],
                )
              : null,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            _SettingsTile(
              title: 'Replay tutorial',
              subtitle: 'Show the home guided tour again',
              isPremiumMode: isPremiumMode,
              premiumIcon: HugeIcons.strokeRoundedHome01,
              onTap: () async {
                await TutorialPrefs.resetHomeTutorialOnly();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  TutorialReplayBus.requestDashboardReplay();
                });
              },
            ),
            const SizedBox(height: 14),
            _SectionTitle(
              title: 'APPEARANCE',
              accentColor: isPremiumMode
                  ? _premiumBlue
                  : const Color(0xFF7C3AED),
              isPremiumMode: isPremiumMode,
            ),
            const SizedBox(height: 6),
            _SettingsTile(
              title: 'Appearance',
              subtitle: appearance == AppAppearance.premium
                  ? 'Premium ELECOM glassmorphism style'
                  : 'Light mode, dark mode, or follow system setting',
              isPremiumMode: isPremiumMode,
              premiumIcon: HugeIcons.strokeRoundedUserStar01,
              onTap: () => _showThemeModeSelector(context),
            ),
            const SizedBox(height: 18),
            _SectionTitle(
              title: 'PRIVACY AND SECURITY',
              accentColor: _premiumBlue,
              isPremiumMode: isPremiumMode,
            ),
            const SizedBox(height: 6),
            _SettingsTile(
              title: 'Notification Settings',
              isPremiumMode: isPremiumMode,
              premiumIcon: HugeIcons.strokeRoundedNotification03,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                );
              },
            ),
            _SettingsTile(
              title: 'Account Settings',
              isPremiumMode: isPremiumMode,
              premiumIcon: HugeIcons.strokeRoundedUserCircle,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AccountSettingsScreen(),
                  ),
                );
              },
            ),
            _SettingsTile(
              title: 'Change Password',
              isPremiumMode: isPremiumMode,
              premiumIcon: HugeIcons.strokeRoundedUserShield01,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            _SectionTitle(
              title: 'ABOUT Elecom',
              accentColor: isPremiumMode
                  ? _premiumBlue
                  : const Color(0xFFF59E0B),
              isPremiumMode: isPremiumMode,
            ),
            const SizedBox(height: 6),
            _SettingsTile(
              title: 'Terms and Conditions',
              isPremiumMode: isPremiumMode,
              premiumIcon: HugeIcons.strokeRoundedBookOpen01,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ElecomTermsConditionsScreen(),
                  ),
                );
              },
            ),
            _SettingsTile(
              title: 'Privacy Notice',
              isPremiumMode: isPremiumMode,
              premiumIcon: HugeIcons.strokeRoundedShieldBlockchain,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ElecomPrivacyNoticeScreen(),
                  ),
                );
              },
            ),
            _SettingsTile(
              title: 'App Version',
              trailingText: _appVersion,
              isPremiumMode: isPremiumMode,
              premiumIcon: HugeIcons.strokeRoundedCheckList,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showThemeModeSelector(BuildContext context) async {
    final notifier = context.read<ThemeNotifier>();
    final currentMode = notifier.appearance;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isPremiumMode = currentMode == AppAppearance.premium;
    final sheetColor = isPremiumMode
        ? Colors.white
        : isDarkMode
        ? const Color(0xFF2A2A35)
        : Colors.white;
    final titleColor = isPremiumMode
        ? _premiumInk
        : isDarkMode
        ? Colors.white
        : Colors.black;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 10,
            right: 10,
            bottom: safeBottom + 10,
          ),
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
                          color: isDarkMode
                              ? Colors.white24
                              : isPremiumMode
                              ? _premiumBlue.withValues(alpha: 0.18)
                              : Theme.of(ctx).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          if (isPremiumMode) ...[
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedUserStar01,
                              color: _premiumBlue,
                              size: 20,
                              strokeWidth: 1.9,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            'Choose appearance',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<AppAppearance>(
                      groupValue: currentMode,
                      onChanged: (mode) => _applyTheme(ctx, mode),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ThemeModeTile(
                            title: 'Light mode',
                            value: AppAppearance.light,
                            isPremiumFlow: isPremiumMode,
                          ),
                          _ThemeModeTile(
                            title: 'Dark mode',
                            value: AppAppearance.dark,
                            isPremiumFlow: isPremiumMode,
                          ),
                          _ThemeModeTile(
                            title: 'Premium mode',
                            subtitle: 'ELECOM glassmorphism style',
                            value: AppAppearance.premium,
                            icon: Icons.auto_awesome_rounded,
                            premiumIcon: HugeIcons.strokeRoundedUserStar01,
                            isPremiumFlow: isPremiumMode,
                          ),
                          _ThemeModeTile(
                            title: 'System default',
                            subtitle: 'Follows your phone appearance setting',
                            value: AppAppearance.system,
                            isPremiumFlow: isPremiumMode,
                          ),
                        ],
                      ),
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

  void _applyTheme(BuildContext context, AppAppearance? mode) {
    if (mode == null) return;
    context.read<ThemeNotifier>().setAppearance(mode);
    Navigator.of(context).pop();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.accentColor,
    required this.isPremiumMode,
  });

  final String title;
  final Color accentColor;
  final bool isPremiumMode;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isPremiumMode
        ? _premiumInk
        : isDarkMode
        ? Colors.white
        : Colors.black;
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
            color: textColor,
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
    required this.isPremiumMode,
    this.subtitle,
    this.trailingText,
    this.premiumIcon,
  });

  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback onTap;
  final bool isPremiumMode;
  final List<List<dynamic>>? premiumIcon;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isPremiumMode
        ? _premiumInk
        : isDarkMode
        ? Colors.white
        : Colors.black;
    final subColor = isPremiumMode
        ? _premiumSub
        : isDarkMode
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;

    final tile = ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: isPremiumMode ? 12 : 2,
        vertical: isPremiumMode ? 4 : 2,
      ),
      leading: isPremiumMode && premiumIcon != null
          ? Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _premiumBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: HugeIcon(
                icon: premiumIcon!,
                color: _premiumBlue,
                size: 21,
                strokeWidth: 1.9,
              ),
            )
          : null,
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w800, color: titleColor),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: subColor),
            ),
      trailing: trailingText != null
          ? Text(
              trailingText!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: subColor,
              ),
            )
          : isPremiumMode
          ? HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: _premiumBlue.withValues(alpha: 0.70),
              size: 20,
              strokeWidth: 1.9,
            )
          : Icon(
              Icons.chevron_right,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
      onTap: onTap,
    );

    if (!isPremiumMode) return tile;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: tile,
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.title,
    required this.value,
    required this.isPremiumFlow,
    this.subtitle,
    this.icon,
    this.premiumIcon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<List<dynamic>>? premiumIcon;
  final AppAppearance value;
  final bool isPremiumFlow;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final groupValue = RadioGroup.maybeOf<AppAppearance>(context)?.groupValue;
    final selected = value == groupValue;
    final isPremium = value == AppAppearance.premium;
    final activeColor = isPremium ? _premiumBlue : null;
    final titleColor = isPremiumFlow
        ? (selected ? _premiumBlue : _premiumInk)
        : selected && isPremium
        ? const Color(0xFFFACC15)
        : (isDarkMode ? Colors.white : Colors.black);

    return RadioListTile<AppAppearance>(
      value: value,
      secondary: isPremiumFlow && premiumIcon != null
          ? HugeIcon(
              icon: premiumIcon!,
              color: selected ? _premiumBlue : _premiumSub,
              size: 22,
              strokeWidth: 1.9,
            )
          : icon == null
          ? null
          : Icon(
              icon,
              color: selected
                  ? const Color(0xFFFACC15)
                  : (isDarkMode ? Colors.white70 : Colors.black54),
            ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isPremiumFlow ? FontWeight.w800 : FontWeight.w700,
          color: titleColor,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                color: isPremiumFlow
                    ? _premiumSub
                    : isDarkMode
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
      fillColor: WidgetStatePropertyAll<Color>(
        activeColor ?? (isDarkMode ? Colors.white70 : Colors.black),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
