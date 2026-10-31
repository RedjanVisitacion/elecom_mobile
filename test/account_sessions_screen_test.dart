import 'dart:convert';

import 'package:elecom_mobile/core/network/api_client.dart';
import 'package:elecom_mobile/features/elecom/data/elecom_mobile_api.dart';
import 'package:elecom_mobile/features/elecom/profile/account_sessions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Future<void> showScreen(
    WidgetTester tester,
    void Function(Map<String, dynamic>) onLogout,
  ) async {
    final api = ElecomMobileApi(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          onLogout(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({'ok': true, 'current_session_ended': true}),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'ok': true,
            'sessions': [
              {
                'id': 'opaque-device-id',
                'device_name': 'ELECOM Mobile - itel A667LP',
                'is_current': true,
                'ip_address': '203.0.113.9',
                'signed_in_at': '2026-11-01T01:00:00Z',
                'last_active_at': '2026-11-01T01:05:00Z',
              },
            ],
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: AccountSessionsScreen(api: api)));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'device details and confirmation are shown; cancel does not revoke',
    (tester) async {
      var revoked = false;
      await showScreen(tester, (_) => revoked = true);
      expect(find.text('ELECOM Mobile - itel A667LP'), findsOneWidget);
      expect(find.text('This device'), findsOneWidget);
      expect(find.textContaining('203.0.113.9'), findsOneWidget);
      expect(find.text('opaque-device-id'), findsNothing);
      await tester.ensureVisible(find.text('Log out all devices'));
      await tester.tap(find.text('Log out all devices'));
      await tester.pumpAndSettle();
      expect(find.text('Log out all devices?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(revoked, isFalse);
    },
  );

  testWidgets(
    'confirmed all-device logout requests revocation and ends the local session',
    (tester) async {
      Map<String, dynamic>? payload;
      final before = ApiClient.sessionEnded.value;
      await showScreen(tester, (data) => payload = data);
      await tester.ensureVisible(find.text('Log out all devices'));
      await tester.tap(find.text('Log out all devices'));
      await tester.pumpAndSettle();
      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Log out'),
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(payload, {'all': true});
      expect(ApiClient.sessionEnded.value, before + 1);
    },
  );
}
