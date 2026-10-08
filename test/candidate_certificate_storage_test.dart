import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:elecom_mobile/features/elecom/data/elecom_mobile_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final pdf = Uint8List.fromList(ascii.encode('%PDF-1.7\nCOC\n%%EOF'));

  test('loads the admin certificate settings for mobile preview', () async {
    final client = MockClient((request) async {
      expect(
        request.url.path,
        '/api/mobile/certificate-of-candidacy/settings/',
      );
      return http.Response(
        '{"ok":true,"forms":{"usg":{"academic_year":"2025 - 2026","chairperson_name":"Sample Chairperson"}},"date_source":"initial_approval"}',
        200,
      );
    });
    addTearDown(client.close);
    final settings = await ElecomMobileApi(
      client: client,
    ).getCandidateCertificateSettings();
    expect(settings['forms']['usg']['academic_year'], '2025 - 2026');
    expect(settings['date_source'], 'initial_approval');
  });

  test('filing sends completed PDF together with candidate details', () async {
    final directory = await Directory.systemTemp.createTemp('coc_storage_');
    addTearDown(() => directory.delete(recursive: true));
    final photo = await File(
      '${directory.path}/photo.png',
    ).writeAsBytes([1, 2]);
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/candidate-applications/submit/'));
      expect(request.body, contains('name="certificate_pdf"'));
      expect(request.body, contains('filename="certificate_of_candidacy.pdf"'));
      expect(request.body, contains('%PDF-1.7'));
      expect(request.body, contains('name="signature_base64"'));
      return http.Response(
        '{"ok":true,"application":{"id":7,"certificate_available":true}}',
        200,
      );
    });
    addTearDown(client.close);
    final result = await ElecomMobileApi(client: client)
        .submitCandidateApplication(
          fields: {'student_id': 'student', 'signature_base64': 'signature'},
          candidatePhoto: photo,
          certificatePdf: pdf,
        );
    expect(result['application']['certificate_available'], true);
  });

  test('retrieves the PDF from server using the application id', () async {
    final client = MockClient((request) async {
      expect(
        request.url.path,
        endsWith('/candidate-applications/7/certificate/'),
      );
      expect(request.headers['Accept'], 'application/pdf');
      return http.Response.bytes(
        pdf,
        200,
        headers: {'content-type': 'application/pdf'},
      );
    });
    addTearDown(client.close);
    expect(
      await ElecomMobileApi(client: client).getCandidateCertificate('7'),
      pdf,
    );
  });

  test(
    'rejects HTML and unauthorized responses as certificate downloads',
    () async {
      for (final status in [200, 401, 404]) {
        final client = MockClient(
          (_) async => http.Response('<html>Error</html>', status),
        );
        addTearDown(client.close);
        await expectLater(
          ElecomMobileApi(client: client).getCandidateCertificate('7'),
          throwsA(isA<ElecomApiException>()),
        );
      }
    },
  );

  test('uploads a legacy device copy to its own application archive', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.path,
        endsWith('/candidate-applications/7/certificate/'),
      );
      expect(request.body, contains('name="certificate_pdf"'));
      return http.Response('{"ok":true,"certificate_available":true}', 200);
    });
    addTearDown(client.close);
    final result = await ElecomMobileApi(
      client: client,
    ).archiveCandidateCertificate('7', pdf);
    expect(result['certificate_available'], true);
  });
}
