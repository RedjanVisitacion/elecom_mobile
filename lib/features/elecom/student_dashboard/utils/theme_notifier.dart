import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppAppearance {
  light,
  dark,
  premium,
  system;

  String get label {
    return switch (this) {
      AppAppearance.light => 'Light mode',
      AppAppearance.dark => 'Dark mode',
      AppAppearance.premium => 'Premium mode',
      AppAppearance.system => 'System default',
    };
  }
}

class ThemeNotifier extends ChangeNotifier {
  static const _prefsKey = 'elecom.appearance.mode.v1';

  AppAppearance _appearance = AppAppearance.system;
  AppAppearance get appearance => _appearance;

  ThemeMode get themeMode {
    return switch (_appearance) {
      AppAppearance.light => ThemeMode.light,
      AppAppearance.dark => ThemeMode.dark,
      AppAppearance.premium => ThemeMode.light,
      AppAppearance.system => ThemeMode.system,
    };
  }

  bool get isDarkMode => _appearance == AppAppearance.dark;
  bool get isPremiumMode => _appearance == AppAppearance.premium;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    AppAppearance? saved;
    for (final mode in AppAppearance.values) {
      if (mode.name == raw) {
        saved = mode;
        break;
      }
    }
    if (saved == null || saved == _appearance) return;
    _appearance = saved;
    notifyListeners();
  }

  Future<void> setAppearance(AppAppearance mode) async {
    if (_appearance == mode) return;
    _appearance = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  void setThemeMode(ThemeMode mode) {
    final appearance = switch (mode) {
      ThemeMode.light => AppAppearance.light,
      ThemeMode.dark => AppAppearance.dark,
      ThemeMode.system => AppAppearance.system,
    };
    setAppearance(appearance);
  }

  void toggleTheme() {
    setThemeMode(
      themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}

final ThemeNotifier themeNotifier = ThemeNotifier();
