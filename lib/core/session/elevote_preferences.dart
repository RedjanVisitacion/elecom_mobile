import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EleVotePreferences {
  EleVotePreferences._();

  static const _kAssistantEnabled = 'elecom.elevote.assistant_enabled';
  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(true);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabledNotifier.value = prefs.getBool(_kAssistantEnabled) ?? true;
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAssistantEnabled) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAssistantEnabled, value);
    enabledNotifier.value = value;
  }
}
