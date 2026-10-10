import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'biometric_laser.dart';

/// Decorative capture guide; this illustration does not perform face analysis.
class BiometricScanGuide extends StatefulWidget {
  const BiometricScanGuide({super.key});

  @override
  State<BiometricScanGuide> createState() => _BiometricScanGuideState();
}

class _BiometricScanGuideState extends State<BiometricScanGuide>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _scan;
  bool _resumed = true;
  bool _motionEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
      value: 0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionEnabled =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncAnimation();
  }

  void _syncAnimation() {
    if (_motionEnabled && _resumed) {
      if (!_scan.isAnimating) _scan.repeat();
    } else {
      _scan.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Illustrated biometric face scan guide',
    child: RepaintBoundary(
      child: SizedBox(
        width: 190,
        height: 220,
        child: CustomPaint(painter: _ScanGuidePainter(_scan)),
      ),
    ),
  );
}

class _ScanGuidePainter extends CustomPainter {
  _ScanGuidePainter(this.scan) : super(repaint: scan);
  final Animation<double> scan;
  static const blue = Color(0xFF2563EB);
  static const cyan = Color(0xFF00F0FF);

  @override
  void paint(Canvas canvas, Size size) {
    // A normalized canvas keeps the vector aligned at any rendered size.
    canvas.save();
    canvas.scale(size.width / 190, size.height / 220);
    final pulse = .5 + .5 * math.sin(scan.value * math.pi * 2);
    final oval = Rect.fromLTWH(24, 8, 142, 204);
    canvas.drawOval(
      oval,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFF4FCFF), Color(0xFFEAF1FF)],
        ).createShader(oval),
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawOval(oval, stroke..color = blue.withValues(alpha: .18));

    final face = Path()
      ..moveTo(95, 31)
      ..cubicTo(59, 31, 48, 53, 51, 91)
      ..cubicTo(47, 115, 59, 161, 78, 181)
      ..quadraticBezierTo(95, 196, 112, 181)
      ..cubicTo(131, 161, 143, 115, 139, 91)
      ..cubicTo(142, 53, 131, 31, 95, 31)
      ..close();
    canvas.drawPath(
      face,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x112563EB), Color(0x2200F0FF)],
        ).createShader(oval),
    );
    canvas.drawPath(
      face,
      stroke
        ..color = blue.withValues(alpha: .55)
        ..strokeWidth = 1.2,
    );

    canvas.save();
    canvas.clipPath(face);
    final mesh = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .65
      ..shader = LinearGradient(
        colors: [blue.withValues(alpha: .17), cyan.withValues(alpha: .45)],
      ).createShader(oval);
    // Bowed meridians and cross-sections imply volume without a bitmap asset.
    for (var i = -5; i <= 5; i++) {
      final x = 95 + i * 9.0;
      canvas.drawPath(
        Path()
          ..moveTo(x, 30)
          ..cubicTo(x + i * 3, 80, x - i * 5, 145, 95 + i * 4, 193),
        mesh,
      );
    }
    for (var i = 0; i < 16; i++) {
      final y = 39 + i * 10.0;
      canvas.drawPath(
        Path()
          ..moveTo(43, y)
          ..quadraticBezierTo(95, y + 16, 147, y),
        mesh,
      );
    }
    final beamY = BiometricLaser.paint(
      canvas,
      const Rect.fromLTWH(43, 30, 104, 164),
      scan.value,
    );
    canvas.restore();

    // Facial contours make the guide recognizable before the mesh animates.
    final features = Paint()
      ..color = blue.withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (final x in [74.0, 116.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 91), width: 22, height: 10),
        features,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(95, 96)
        ..lineTo(88, 126)
        ..quadraticBezierTo(95, 132, 102, 126),
      features,
    );
    canvas.drawPath(
      Path()
        ..moveTo(77, 149)
        ..quadraticBezierTo(95, 142, 113, 149)
        ..quadraticBezierTo(95, 159, 77, 149),
      features,
    );
    const nodes = [
      Offset(74, 91),
      Offset(116, 91),
      Offset(95, 126),
      Offset(59, 132),
      Offset(131, 132),
      Offset(77, 149),
      Offset(113, 149),
      Offset(72, 174),
      Offset(118, 174),
      Offset(95, 187),
    ];
    for (var i = 0; i < nodes.length; i++) {
      final intensity = BiometricLaser.intersection(nodes[i].dy, beamY, 13);
      canvas.drawCircle(
        nodes[i],
        3.5 + intensity * 2,
        Paint()
          ..color = cyan.withValues(alpha: .12 + intensity * .18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        nodes[i],
        1.8 + intensity * .7,
        Paint()
          ..color = Color.lerp(blue.withValues(alpha: .55), cyan, intensity)!,
      );
    }
    for (final corner in [
      const Offset(38, 19),
      const Offset(152, 19),
      const Offset(38, 201),
      const Offset(152, 201),
    ]) {
      final dx = corner.dx < 95 ? 1.0 : -1.0;
      final dy = corner.dy < 110 ? 1.0 : -1.0;
      final bracket = Path()
        ..moveTo(corner.dx, corner.dy + dy * 15)
        ..lineTo(corner.dx, corner.dy)
        ..lineTo(corner.dx + dx * 15, corner.dy);
      canvas.drawPath(
        bracket,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = cyan.withValues(alpha: .15 + pulse * .25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawPath(
        bracket,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = blue.withValues(alpha: .6 + pulse * .4),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScanGuidePainter oldDelegate) =>
      oldDelegate.scan != scan;
}
