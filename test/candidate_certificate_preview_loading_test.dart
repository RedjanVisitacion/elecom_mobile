import 'dart:async';
import 'dart:typed_data';

import 'package:elecom_mobile/features/elecom/candidates/candidate_certificate_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'certificate opens while download is pending and Back stays usable',
    (tester) async {
      final download = Completer<Uint8List>();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CandidateCertificatePreviewScreen(
                      bytes: Uint8List(0),
                      fileName: 'USG_Certificate_of_Candidacy_Test.pdf',
                      loadCertificate: () => download.future,
                    ),
                  ),
                ),
                child: const Text('View COC'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('View COC'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Preparing your certificate…'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('View COC'), findsOneWidget);
      download.complete(Uint8List(0));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed load shows retry and retries the download', (
    tester,
  ) async {
    var attempts = 0;
    final pending = Completer<Uint8List>();
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateCertificatePreviewScreen(
          bytes: Uint8List(0),
          fileName: 'test.pdf',
          loadCertificate: () {
            attempts++;
            return attempts == 1
                ? Future.error(StateError('offline'))
                : pending.future;
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(attempts, 2);
    expect(find.text('Preparing your certificate…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    pending.complete(Uint8List(0));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
