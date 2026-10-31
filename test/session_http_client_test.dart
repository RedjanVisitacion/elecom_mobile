import 'dart:async';

import 'package:elecom_mobile/core/network/session_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final origin = Uri.parse('https://elecom.test');

  test(
    'mutations attach CSRF, same-origin referrer, and device metadata',
    () async {
      final client = SessionHttpClient(
        apiOrigin: origin,
        deviceName: 'Test Android',
        inner: MockClient((request) async {
          expect(request.headers['cookie'], contains('sessionid=session-a'));
          expect(request.headers['X-CSRFToken'], 'csrf-value');
          expect(request.headers['Referer'], 'https://elecom.test/');
          expect(request.headers['X-ELECOM-Device'], 'Test Android');
          return http.Response('{"ok":true}', 200);
        }),
      );
      client.importCookies({
        'sessionid': 'session-a',
        'csrftoken': 'csrf-value',
      });
      await client.post(origin.resolve('/logout/'));
      client.close();
    },
  );

  test(
    '401 expires an authenticated session even if the server clears its cookie',
    () async {
      var ended = 0;
      final client = SessionHttpClient(
        apiOrigin: origin,
        deviceName: 'Test',
        onUnauthorized: () => ended++,
        inner: MockClient(
          (_) async => http.Response(
            '{}',
            401,
            headers: {'set-cookie': 'sessionid=; Path=/; Max-Age=0'},
          ),
        ),
      );
      client.importCookies({'sessionid': 'old-session'});
      await client.get(origin.resolve('/api/mobile/account/profile/'));
      expect(ended, 1);
      expect(client.exportCookies().containsKey('sessionid'), isFalse);
      client.close();
    },
  );

  test(
    'late unauthorized response cannot clear or end a newer login',
    () async {
      var ended = 0;
      final response = Completer<http.Response>();
      final entered = Completer<void>();
      final client = SessionHttpClient(
        apiOrigin: origin,
        deviceName: 'Test',
        onUnauthorized: () => ended++,
        inner: MockClient((_) {
          entered.complete();
          return response.future;
        }),
      );
      client.importCookies({'sessionid': 'old-session'});
      final pending = client.get(
        origin.resolve('/api/mobile/account/profile/'),
      );
      await entered.future;
      client.importCookies({'sessionid': 'new-session'});
      response.complete(
        http.Response('{}', 401, headers: {'set-cookie': 'sessionid=; Path=/'}),
      );
      await pending;
      expect(ended, 0);
      expect(client.exportCookies()['sessionid'], 'new-session');
      client.close();
    },
  );

  test('third-party uploads never receive or replace ELECOM cookies', () async {
    var ended = 0;
    final client = SessionHttpClient(
      apiOrigin: origin,
      deviceName: 'Test',
      onUnauthorized: () => ended++,
      inner: MockClient((request) async {
        expect(request.headers.containsKey('cookie'), isFalse);
        expect(request.headers.containsKey('X-CSRFToken'), isFalse);
        expect(request.headers.containsKey('X-ELECOM-Device'), isFalse);
        return http.Response(
          '{}',
          401,
          headers: {'set-cookie': 'sessionid=untrusted; Path=/'},
        );
      }),
    );
    client.importCookies({
      'sessionid': 'real-session',
      'csrftoken': 'real-csrf',
    });
    await client.post(Uri.parse('https://uploads.example.test/image'));
    expect(ended, 0);
    expect(client.exportCookies()['sessionid'], 'real-session');
    client.close();
  });

  test(
    'an anonymous bad-login response does not emit a session-expired event',
    () async {
      var ended = 0;
      final client = SessionHttpClient(
        apiOrigin: origin,
        deviceName: 'Test',
        onUnauthorized: () => ended++,
        inner: MockClient((_) async => http.Response('{}', 401)),
      );
      await client.post(origin.resolve('/login/'));
      expect(ended, 0);
      client.close();
    },
  );
  test('bad credentials cannot end an already valid session', () async {
    var ended = 0;
    final client = SessionHttpClient(
      apiOrigin: origin,
      deviceName: 'Test',
      onUnauthorized: () => ended++,
      inner: MockClient((_) async => http.Response('{}', 401)),
    );
    client.importCookies({'sessionid': 'valid-session'});
    await client.post(origin.resolve('/login/'));
    expect(ended, 0);
    expect(client.exportCookies()['sessionid'], 'valid-session');
    client.close();
  });
}
