import 'dart:async';

import 'package:elecom_mobile/core/notifications/notification_center_store.dart';
import 'package:elecom_mobile/core/session/user_session.dart';
import 'package:elecom_mobile/features/elecom/data/elecom_mobile_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NotificationsApi extends ElecomMobileApi {
  List<Map<String, dynamic>> notifications = [];
  int requests = 0;
  bool fail = false;
  Completer<List<Map<String, dynamic>>>? pending;
  @override
  Future<List<Map<String, dynamic>>> getNotifications() async {
    requests++;
    if (pending != null) return pending!.future;
    if (fail) throw Exception('Offline');
    return notifications;
  }
}

Map<String, dynamic> _filingNotification(int id) => {
  'id': id,
  'type': 'candidate_filing',
  'title': 'Initial filing approved',
  'body': 'Submit your requirements.',
  'created_at': '2026-10-07T12:00:00Z',
  'read_at': null,
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'elecom.notifications.push_enabled': false,
    });
    UserSession.studentId = 'student';
  });
  tearDown(() {
    NotificationCenterStore.clearLocal();
    UserSession.clear();
  });

  testWidgets(
    'app-wide polling updates inbox and badge and retains data offline',
    (tester) async {
      final api = _NotificationsApi();
      NotificationCenterStore.setApiForTesting(api);
      await NotificationCenterStore.init(forceRefresh: true);
      api.notifications = [_filingNotification(1)];
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(
        NotificationCenterStore.items.value.single['type'],
        'candidate_filing',
      );
      expect(NotificationCenterStore.unreadCount.value, 1);
      api.fail = true;
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(NotificationCenterStore.items.value.length, 1);
      expect(NotificationCenterStore.unreadCount.value, 1);
      NotificationCenterStore.clearLocal();
    },
  );

  testWidgets('background polling pauses and resume refreshes immediately', (
    tester,
  ) async {
    final api = _NotificationsApi();
    NotificationCenterStore.setApiForTesting(api);
    await NotificationCenterStore.init(forceRefresh: true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final requests = api.requests;
    await tester.pump(const Duration(seconds: 6));
    expect(api.requests, requests);
    api.notifications = [_filingNotification(2)];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(NotificationCenterStore.items.value.single['id'], 2);
    NotificationCenterStore.clearLocal();
  });

  testWidgets('requests do not overlap or restore the inbox after logout', (
    tester,
  ) async {
    final api = _NotificationsApi();
    NotificationCenterStore.setApiForTesting(api);
    await NotificationCenterStore.init(forceRefresh: true);
    api.pending = Completer<List<Map<String, dynamic>>>();
    await tester.pump(const Duration(seconds: 3));
    final requests = api.requests;
    await tester.pump(const Duration(seconds: 9));
    expect(api.requests, requests);
    NotificationCenterStore.clearLocal();
    UserSession.clear();
    api.pending!.complete([_filingNotification(3)]);
    await tester.pump();
    expect(NotificationCenterStore.items.value, isEmpty);
    expect(NotificationCenterStore.unreadCount.value, 0);
  });
}
