import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Captures handwritten ink on a fixed white canvas for the certificate.
class CandidateSignatureScreen extends StatefulWidget {
  const CandidateSignatureScreen({super.key});

  @override
  State<CandidateSignatureScreen> createState() =>
      _CandidateSignatureScreenState();
}

class _CandidateSignatureScreenState extends State<CandidateSignatureScreen> {
  final List<List<Offset>> _strokes = [];
  Size _canvasSize = Size.zero;
  bool _saving = false;

  bool get _hasInk => _strokes.any((stroke) => stroke.length > 1);

  Offset _clamp(Offset point) => Offset(
    point.dx.clamp(0, _canvasSize.width),
    point.dy.clamp(0, _canvasSize.height),
  );

  Future<void> _save() async {
    if (!_hasInk || _saving) return;
    setState(() => _saving = true);
    final points = _strokes
        .where((stroke) => stroke.length > 1)
        .expand((stroke) => stroke);
    var bounds = Rect.fromPoints(points.first, points.first);
    for (final point in points) {
      bounds = bounds.expandToInclude(Rect.fromPoints(point, point));
    }
    bounds = bounds.inflate(8);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(2);
    canvas.drawRect(Offset.zero & bounds.size, Paint()..color = Colors.white);
    canvas.translate(-bounds.left, -bounds.top);
    _InkPainter(_strokes).paint(canvas, _canvasSize);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (bounds.width * 2).ceil(),
      (bounds.height * 2).ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (!mounted) return;
    if (data == null) {
      setState(() => _saving = false);
      return;
    }
    Navigator.pop<Uint8List>(context, data.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Candidate Signature')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign inside the box using your finger. Your signature will appear on your Certificate of Candidacy.',
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 2.5,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _canvasSize = constraints.biggest;
                return Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey),
                  ),
                  child: GestureDetector(
                    onPanStart: _saving
                        ? null
                        : (details) => setState(
                            () => _strokes.add([_clamp(details.localPosition)]),
                          ),
                    onPanUpdate: _saving
                        ? null
                        : (details) => setState(
                            () => _strokes.last.add(
                              _clamp(details.localPosition),
                            ),
                          ),
                    child: CustomPaint(
                      key: const ValueKey('candidate-signature-canvas'),
                      painter: _InkPainter(_strokes),
                      size: Size.infinite,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _saving ? null : () => setState(_strokes.clear),
            icon: const Icon(Icons.clear),
            label: const Text('Clear Signature'),
          ),
          FilledButton(
            onPressed: _hasInk && !_saving ? _save : null,
            child: Text(_saving ? 'Saving...' : 'Use Signature'),
          ),
        ],
      ),
    ),
  );
}

class _InkPainter extends CustomPainter {
  const _InkPainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final pen = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, pen);
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) => true;
}
