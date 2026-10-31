import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:shared_preferences/shared_preferences.dart';

class EleVotePreferences {
  EleVotePreferences._();

  static const _kAssistantEnabled = 'elecom.elevote.assistant_enabled';
  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(true);

  // Temporary dismissal is kept in memory, never in the saved preference.
  static final ValueNotifier<bool> dismissedNotifier = ValueNotifier<bool>(
    false,
  );
  static final _sessionLifecycle = _EleVoteSessionLifecycle();
  static bool _observingLifecycle = false;

  static bool get assistantVisible =>
      enabledNotifier.value && !dismissedNotifier.value;

  static void dismissForSession() {
    dismissedNotifier.value = true;
  }

  static Future<void> load() async {
    if (!_observingLifecycle) {
      WidgetsBinding.instance.addObserver(_sessionLifecycle);
      _observingLifecycle = true;
    }
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

class _EleVoteSessionLifecycle with WidgetsBindingObserver {
  bool _wasBackgrounded = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      EleVotePreferences.dismissedNotifier.value = false;
    }
  }
}
