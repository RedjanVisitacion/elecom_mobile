import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import 'candidate_filing_theme.dart';

String candidateCertificateFileName({
  required String organization,
  required String candidateName,
}) {
  String safe(String value) => value
      .trim()
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '');
  final name = safe(candidateName);
  final org = safe(organization.toUpperCase());
  return '${org.isEmpty ? 'Candidate' : org}_Certificate_of_Candidacy_'
      '${name.isEmpty ? 'Candidate' : name}.pdf';
}

class CandidateCertificatePreviewScreen extends StatefulWidget {
  const CandidateCertificatePreviewScreen({
    super.key,
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;

  @override
  State<CandidateCertificatePreviewScreen> createState() =>
      _CandidateCertificatePreviewScreenState();
}

class _CandidateCertificatePreviewScreenState
    extends State<CandidateCertificatePreviewScreen> {
  bool _saving = false;

  Future<void> _download() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final destination = await FilePicker.saveFile(
        dialogTitle: 'Save Certificate of Candidacy',
        fileName: widget.fileName,
        bytes: widget.bytes,
        mimeType: 'application/pdf',
      );
      if (!mounted || destination == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved ${widget.fileName}')));
    } catch (error) {
      debugPrint('COC download failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the PDF. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => CandidateFilingStyle(
    child: Scaffold(
      appBar: AppBar(title: const Text('Certificate of Candidacy')),
      body: PdfPreview(
        build: (_) async => widget.bytes,
        pdfFileName: widget.fileName,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            onPressed: _saving ? null : _download,
            icon: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_outlined),
          ),
        ],
      ),
    ),
  );
}
