import 'package:elecom_mobile/features/elecom/data/elecom_mobile_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'pre-verification reads recover from one connection interruption',
    () async {
      for (final route in ['window', 'status', 'enrollment']) {
        var calls = 0;
        final api = ElecomMobileApi(
          client: MockClient((request) async {
            calls++;
            if (calls == 1) throw http.ClientException('Connection reset');
            return http.Response('{"ok":true,"enrolled":true}', 200);
          }),
        );
        final result = await switch (route) {
          'window' => api.getElectionWindow(),
          'status' => api.getVoteStatus(),
          _ => api.getFaceEnrollmentStatus(),
        };
        expect(result['ok'], true);
        expect(calls, 2);
      }
    },
  );

  test('persistent connection failure stops after two attempts', () async {
    var calls = 0;
    final api = ElecomMobileApi(
      client: MockClient((request) async {
        calls++;
        throw http.ClientException('Offline');
      }),
    );
    await expectLater(
      api.getFaceEnrollmentStatus(),
      throwsA(
        isA<ElecomApiException>()
            .having((e) => e.code, 'code', 'network_unavailable')
            .having((e) => e.message, 'message', contains('Retry')),
      ),
    );
    expect(calls, 2);
  });

  test('server rejection is preserved without retry', () async {
    var calls = 0;
    final api = ElecomMobileApi(
      client: MockClient((request) async {
        calls++;
        return http.Response(
          '{"ok":false,"error":"Sign in again","code":"unauthorized"}',
          401,
        );
      }),
    );
    await expectLater(
      api.getFaceEnrollmentStatus(),
      throwsA(
        isA<ElecomApiException>().having((e) => e.code, 'code', 'unauthorized'),
      ),
    );
    expect(calls, 1);
  });
}
