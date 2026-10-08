import 'dart:io';
import 'dart:convert';

import 'package:elecom_mobile/features/elecom/candidates/candidate_certificate.dart';
import 'package:elecom_mobile/features/elecom/candidates/candidate_signature_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('age changes on the birthday, including the year boundary', () {
    final birthday = DateTime(2005, 7, 9);
    expect(candidateAge(birthday, DateTime(2026, 7, 8)), 20);
    expect(candidateAge(birthday, DateTime(2026, 7, 9)), 21);
    expect(candidateAge(DateTime(2005, 12, 31), DateTime(2026, 1, 1)), 20);
  });

  test(
    'certificate generates a PDF with photo, signature and all memberships',
    () async {
      final image = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAFElEQVR4nGN4RiJgGNUwqmH4agAA0PCyH/oS3CQAAAAASUVORK5CYII=',
      );
      final result = await buildCandidateCertificate(
        fields: {
          'student_id': '2026000001',
          'organization': 'USG',
          'academic_year': '2025 - 2026',
          'chairperson_name': 'Sample COMELEC Chairperson',
          'first_name': 'Sample',
          'middle_name': 'M.',
          'last_name': 'Candidate',
          'curriculum_program': 'Bachelor of Science in Information Technology',
          'major': 'Information Technology',
          'gender': 'Female',
          'date_of_birth': '2005-07-09',
          'age': '21',
          'contact_number': '09123456789',
          'email': 'candidate@example.com',
          'address': 'Oroquieta City, Misamis Occidental',
          'candidate_type': 'Political Party',
          'party_name': 'Sample Party',
          'position': 'BSIT Representative',
          for (var i = 0; i < 3; i++) ...{
            'affiliation_${i}_organization': 'Sample Club ${i + 1}',
            'affiliation_${i}_years': '2 years',
            'affiliation_${i}_position': 'Member',
          },
        },
        photo: image,
        signature: image,
      );
      expect(String.fromCharCodes(result.take(5)), '%PDF-');
      expect(result.length, greaterThan(10000));
      expect(
        String.fromCharCodes(result),
        matches(RegExp(r'/MediaBox\s*\[\s*0\s+0\s+612\s+1008\s*\]')),
      );
      // Optional artifact for inspecting the actual rendered template alignment.
      if (Platform.environment['EXPORT_CERTIFICATE_PREVIEW'] == '1') {
        await File(
          '.dart_tool/candidate-certificate-preview.pdf',
        ).writeAsBytes(result);
      }
    },
  );

  test('certificate supports one membership and empty optional fields', () async {
    final image = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAFElEQVR4nGN4RiJgGNUwqmH4agAA0PCyH/oS3CQAAAAASUVORK5CYII=',
    );
    final result = await buildCandidateCertificate(
      fields: {
        'first_name': 'Redjan Phil',
        'last_name': 'Visitacion',
        'affiliation_0_organization': 'University Student Government (USG)',
        'affiliation_0_years': '2023–2026',
        'affiliation_0_position': 'Member',
      },
      photo: image,
      signature: image,
    );
    expect(String.fromCharCodes(result.take(5)), '%PDF-');
  });

  test('department organizations select the department form', () {
    for (final organization in ['SITE', 'PAFE', 'AFPROTECHS', ' site ']) {
      expect(candidateCertificateUsesDepartmentForm(organization), isTrue);
    }
    expect(candidateCertificateUsesDepartmentForm('USG'), isFalse);
    expect(candidateCertificateUsesDepartmentForm(null), isFalse);
  });

  test(
    'department certificate uses letter size and the department layout',
    () async {
      final image = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAFElEQVR4nGN4RiJgGNUwqmH4agAA0PCyH/oS3CQAAAAASUVORK5CYII=',
      );
      final result = await buildCandidateCertificate(
        fields: {
          'organization': 'SITE',
          'academic_year': '2025 - 2026',
          'chairperson_name': 'Sample COMELEC Chairperson',
          'student_id': '2026000001',
          'first_name': 'Sample',
          'middle_name': 'M.',
          'last_name': 'Candidate',
          'curriculum_program': 'Bachelor of Science in Information Technology',
          'major': 'N/A',
          'gender': 'Female',
          'date_of_birth': '2005-07-09',
          'age': '21',
          'contact_number': '09123456789',
          'email': 'candidate@example.com',
          'address': 'Oroquieta City, Misamis Occidental',
          'candidate_type': 'Independent',
          'position': 'Public Information Officer',
          'affiliation_0_organization':
              'Society of Information Technology Enthusiasts (SITE)',
          'affiliation_0_years': '2023–2026',
          'affiliation_0_position': 'Member',
        },
        photo: image,
        signature: image,
      );
      expect(String.fromCharCodes(result.take(5)), '%PDF-');
      expect(
        String.fromCharCodes(result),
        matches(RegExp(r'/MediaBox\s*\[\s*0\s+0\s+612\s+792\s*\]')),
      );
      if (Platform.environment['EXPORT_CERTIFICATE_PREVIEW'] == '1') {
        await File(
          '.dart_tool/department-certificate-preview.pdf',
        ).writeAsBytes(result);
      }
    },
  );

  testWidgets('signature requires a stroke and Clear removes it', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CandidateSignatureScreen()),
    );
    FilledButton button() =>
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button().onPressed, isNull);
    final canvas = find.byKey(const ValueKey('candidate-signature-canvas'));
    final gesture = await tester.startGesture(tester.getCenter(canvas));
    await gesture.moveBy(const Offset(30, 10));
    await gesture.moveBy(const Offset(30, 10));
    await gesture.up();
    await tester.pump();
    expect(button().onPressed, isNotNull);
    await tester.tap(find.text('Clear Signature'));
    await tester.pump();
    expect(button().onPressed, isNull);
  });
}
