import 'package:elecom_mobile/core/session/elevote_preferences.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('dismissal survives reloads and navigation until app reopening', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    EleVotePreferences.dismissedNotifier.value = false;
    await EleVotePreferences.load();
    expect(EleVotePreferences.assistantVisible, isTrue);

    EleVotePreferences.dismissForSession();
    await EleVotePreferences.load();
    expect(EleVotePreferences.assistantVisible, isFalse);
    expect(await EleVotePreferences.isEnabled(), isTrue);

    // System overlays and focus changes are not a new app session.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(EleVotePreferences.assistantVisible, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(EleVotePreferences.assistantVisible, isTrue);
  });

  testWidgets('reopening respects the saved assistant off setting', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await EleVotePreferences.setEnabled(false);
    EleVotePreferences.dismissForSession();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(EleVotePreferences.dismissedNotifier.value, isFalse);
    expect(EleVotePreferences.assistantVisible, isFalse);
    expect(await EleVotePreferences.isEnabled(), isFalse);
  });
}
