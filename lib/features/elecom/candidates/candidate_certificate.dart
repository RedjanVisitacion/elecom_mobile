import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

int candidateAge(DateTime birthDate, DateTime today) {
  var age = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age--;
  }
  return age;
}

/// USG uses the legal-size form; department organizations use the letter-size form.
bool candidateCertificateUsesDepartmentForm(String? organization) => const [
  'SITE',
  'PAFE',
  'AFPROTECHS',
].contains(organization?.trim().toUpperCase());

Future<Uint8List> buildCandidateCertificate({
  required Map<String, String> fields,
  required Uint8List photo,
  required Uint8List signature,
}) async {
  final department = candidateCertificateUsesDepartmentForm(
    fields['organization'],
  );
  final template = await rootBundle.load(
    department
        ? 'assets/forms/department_certificate_of_candidacy.png'
        : 'assets/forms/certificate_of_candidacy.png',
  );
  final background = pw.MemoryImage(template.buffer.asUint8List());
  final document = pw.Document(
    deflate: zlib.encode,
    title: 'Certificate of Candidacy',
    author: 'ELECOM',
  );
  final fullName = [
    fields['first_name'],
    fields['middle_name'],
    fields['last_name'],
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
  pw.Widget value(
    String text,
    double x,
    double y,
    double width, {
    double height = 11,
    bool whiteBackground = false,
    pw.Alignment alignment = pw.Alignment.centerLeft,
  }) => pw.Positioned(
    left: x,
    top: y,
    child: pw.Container(
      width: width,
      height: height,
      color: whiteBackground ? PdfColors.white : null,
      child: text.trim().isEmpty
          ? pw.SizedBox()
          : pw.FittedBox(
              alignment: alignment,
              fit: pw.BoxFit.scaleDown,
              child: pw.Text(
                text.replaceAll('–', '-').replaceAll('—', '-'),
                style: pw.TextStyle(font: pw.Font.times(), fontSize: 10),
              ),
            ),
    ),
  );
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(612, department ? 792 : 1008, marginAll: 0),
      build: (_) => pw.Stack(
        children: [
          pw.Positioned.fill(child: pw.Image(background, fit: pw.BoxFit.fill)),
          if ((fields['academic_year'] ?? '').isNotEmpty)
            value(
              'Academic Year ${fields['academic_year']}',
              department ? 185.66 : 205.37,
              department ? 580.5 : 556.8,
              department ? 126.5 : 107.2,
              whiteBackground: true,
            ),
          if ((fields['chairperson_name'] ?? '').isNotEmpty)
            value(
              fields['chairperson_name']!,
              department ? 350 : 365,
              department ? 737 : 782,
              department ? 172 : 185,
              whiteBackground: true,
              alignment: pw.Alignment.center,
            ),
          pw.Positioned(
            left: 433,
            top: 109,
            child: pw.Container(
              width: 140,
              height: 130,
              color: PdfColors.white,
              alignment: pw.Alignment.center,
              child: pw.SizedBox(
                width: 128,
                height: 128,
                child: pw.Image(pw.MemoryImage(photo), fit: pw.BoxFit.cover),
              ),
            ),
          ),
          value(fields['student_id'] ?? '', 500, department ? 264 : 258, 75),
          value(fullName, 180, department ? 278 : 271, 393),
          value(
            fields['curriculum_program'] ?? fields['program'] ?? '',
            180,
            department ? 292 : 284,
            393,
          ),
          value(fields['major'] ?? '', 180, department ? 306 : 297, 393),
          value(fields['gender'] ?? '', 112, department ? 348 : 336, 119),
          value(
            fields['date_of_birth'] ?? '',
            316,
            department ? 348 : 336,
            146,
          ),
          value(fields['age'] ?? '', 502, department ? 348 : 336, 72),
          value(
            fields['contact_number'] ?? '',
            112,
            department ? 364 : 352,
            119,
          ),
          value(fields['email'] ?? '', 316, department ? 364 : 352, 258),
          value(fields['address'] ?? '', 112, department ? 378 : 365, 463),
          for (var i = 0; i < 3; i++) ...[
            value(
              fields['affiliation_${i}_organization'] ?? '',
              32,
              department ? 434 + i * 14.16 : 419 + i * 13.2,
              258,
            ),
            value(
              fields['affiliation_${i}_years'] ?? '',
              300,
              department ? 434 + i * 14.16 : 419 + i * 13.2,
              130,
            ),
            value(
              fields['affiliation_${i}_position'] ?? '',
              441,
              department ? 434 + i * 14.16 : 419 + i * 13.2,
              130,
            ),
          ],
          value(
            fields['candidate_type'] == 'Independent'
                ? 'Independent'
                : fields['party_name'] ?? '',
            163,
            department ? 518 : 497,
            412,
          ),
          value(fields['position'] ?? '', 163, department ? 532 : 510, 412),
          value(
            fields['position'] ?? '',
            department ? 214 : 154,
            department ? 592 : 568,
            department ? 64 : 224,
            height: 10,
          ),
          pw.Positioned(
            left: 221,
            top: department ? 643 : 614,
            child: pw.SizedBox(
              width: 170,
              height: department ? 18 : 29,
              child: pw.Center(
                child: pw.Image(
                  pw.MemoryImage(signature),
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return document.save();
}
