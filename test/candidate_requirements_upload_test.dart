import 'dart:convert';
import 'dart:io';

import 'package:elecom_mobile/features/elecom/data/elecom_mobile_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory directory;
  late File document;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('candidate_upload_test_');
    document = await File(
      '${directory.path}/enrollment.pdf',
    ).writeAsString('%PDF-1.4\nTest document');
  });

  tearDown(() => directory.delete(recursive: true));

  test('submits multipart documents and returns the review status', () async {
    final client = MockClient((request) async {
      expect(
        request.url.path,
        endsWith('/candidate-applications/requirements/'),
      );
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      expect(request.body, contains('name="enrollment_certificate"'));
      expect(request.body, contains('filename="enrollment.pdf"'));
      return http.Response(
        jsonEncode({'ok': true, 'status': 'requirements_review'}),
        200,
      );
    });
    addTearDown(client.close);
    final result = await ElecomMobileApi(
      client: client,
    ).submitCandidateRequirements(files: {'enrollment_certificate': document});
    expect(result['status'], 'requirements_review');
  });

  test('HTML 413 is reported as an upload limit, not invalid JSON', () async {
    final client = MockClient(
      (_) async => http.Response('<html>413</html>', 413),
    );
    addTearDown(client.close);
    await expectLater(
      ElecomMobileApi(
        client: client,
      ).submitCandidateRequirements(files: {'grades': document}),
      throwsA(
        isA<ElecomApiException>()
            .having((error) => error.code, 'code', 'upload_too_large')
            .having(
              (error) => error.message,
              'message',
              contains('upload size'),
            ),
      ),
    );
  });

  test(
    'keeps backend validation errors instead of calling them network errors',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'ok': false,
            'error': 'Only PDF documents are accepted.',
          }),
          400,
        ),
      );
      addTearDown(client.close);
      await expectLater(
        ElecomMobileApi(
          client: client,
        ).submitCandidateRequirements(files: {'grades': document}),
        throwsA(
          isA<ElecomApiException>().having(
            (error) => error.message,
            'message',
            contains('Only PDF documents are accepted.'),
          ),
        ),
      );
    },
  );

  test('rejects empty and oversized files before sending a request', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{"ok":true}', 200);
    });
    addTearDown(client.close);
    for (final size in [0, ElecomMobileApi.candidateRequirementMaxBytes + 1]) {
      final handle = await document.open(mode: FileMode.write);
      await handle.truncate(size);
      await handle.close();
      await expectLater(
        ElecomMobileApi(
          client: client,
        ).submitCandidateRequirements(files: {'grades': document}),
        throwsA(
          isA<ElecomApiException>().having(
            (error) => error.code,
            'code',
            'invalid_requirement_size',
          ),
        ),
      );
    }
    expect(requests, 0);
  });
}
