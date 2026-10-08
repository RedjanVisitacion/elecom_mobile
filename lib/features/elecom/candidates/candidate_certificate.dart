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

/// Coordinates follow the supplied 8.5 x 14 inch COMELEC form.
Future<Uint8List> buildCandidateCertificate({
  required Map<String, String> fields,
  required Uint8List photo,
  required Uint8List signature,
}) async {
  final template = await rootBundle.load(
    'assets/forms/certificate_of_candidacy.png',
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
  }) => pw.Positioned(
    left: x,
    top: y,
    child: pw.SizedBox(
      width: width,
      height: height,
      child: text.trim().isEmpty
          ? pw.SizedBox()
          : pw.FittedBox(
              alignment: pw.Alignment.centerLeft,
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
      pageFormat: const PdfPageFormat(612, 1008, marginAll: 0),
      build: (_) => pw.Stack(
        children: [
          pw.Positioned.fill(child: pw.Image(background, fit: pw.BoxFit.fill)),
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
          value(fields['student_id'] ?? '', 496, 258, 75),
          value(fullName, 177, 271, 393),
          value(
            fields['curriculum_program'] ?? fields['program'] ?? '',
            177,
            284,
            393,
          ),
          value(fields['major'] ?? '', 177, 297, 393),
          value(fields['gender'] ?? '', 108, 336, 119),
          value(fields['date_of_birth'] ?? '', 313, 336, 146),
          value(fields['age'] ?? '', 499, 336, 72),
          value(fields['contact_number'] ?? '', 108, 352, 119),
          value(fields['email'] ?? '', 313, 352, 258),
          value(fields['address'] ?? '', 108, 365, 463),
          for (var i = 0; i < 3; i++) ...[
            value(
              fields['affiliation_${i}_organization'] ?? '',
              32,
              419 + i * 13.2,
              258,
            ),
            value(
              fields['affiliation_${i}_years'] ?? '',
              300,
              419 + i * 13.2,
              130,
            ),
            value(
              fields['affiliation_${i}_position'] ?? '',
              441,
              419 + i * 13.2,
              130,
            ),
          ],
          value(
            fields['candidate_type'] == 'Independent'
                ? 'Independent'
                : fields['party_name'] ?? '',
            159,
            497,
            412,
          ),
          value(fields['position'] ?? '', 159, 510, 412),
          value(fields['position'] ?? '', 194, 568, 218, height: 10),
          pw.Positioned(
            left: 221,
            top: 614,
            child: pw.SizedBox(
              width: 170,
              height: 29,
              child: pw.Image(
                pw.MemoryImage(signature),
                fit: pw.BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return document.save();
}
