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
    this.loadCertificate,
  });

  final Uint8List bytes;
  final String fileName;
  final Future<Uint8List> Function()? loadCertificate;

  @override
  State<CandidateCertificatePreviewScreen> createState() =>
      _CandidateCertificatePreviewScreenState();
}

class _CandidateCertificatePreviewScreenState
    extends State<CandidateCertificatePreviewScreen> {
  bool _saving = false;
  late Uint8List _bytes;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bytes = widget.bytes;
    if (widget.loadCertificate != null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await widget.loadCertificate!();
      if (mounted) setState(() => _bytes = bytes);
    } catch (error) {
      debugPrint('COC loading failed: $error');
      if (mounted) {
        setState(
          () => _error = 'Could not load the certificate. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _print() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CandidateFilingStyle(
          child: Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: () => Navigator.pop(context)),
              title: const Text('Print Certificate'),
            ),
            body: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Choose a printer in the device print options. Use your device’s Back button or Cancel to return here.',
                  ),
                ),
                Expanded(
                  child: PdfPreview(
                    build: (_) async => _bytes,
                    useActions: false,
                    canDebug: false,
                    dpi: 96,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () async {
                    try {
                      await Printing.layoutPdf(
                        onLayout: (_) async => _bytes,
                        name: widget.fileName,
                        dynamicLayout: false,
                      );
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not open device print options.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Open device print options'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _download() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final destination = await FilePicker.saveFile(
        dialogTitle: 'Save Certificate of Candidacy',
        fileName: widget.fileName,
        bytes: _bytes,
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
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: const Text('Certificate of Candidacy'),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing your certificate…'),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          : PdfPreview(
              build: (_) async => _bytes,
              pdfFileName: widget.fileName,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              dpi: 96,
              allowPrinting: false,
              actions: [
                IconButton(
                  tooltip: 'Print certificate',
                  onPressed: _print,
                  icon: const Icon(Icons.print_outlined),
                ),
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
