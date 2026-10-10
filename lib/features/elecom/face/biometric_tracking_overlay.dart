import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'biometric_laser.dart';

const _cyan = Color(0xFF00F0FF);
const _teal = Color(0xFF72E8DD);

/// ML Kit upright normalized coordinates match the stretched CameraPreview.
/// The wireframe is a visual guide anchored to sparse landmarks, not a depth scan.
class BiometricTrackingPainter extends CustomPainter {
  BiometricTrackingPainter({
    required this.animation,
    required this.active,
    required this.landmarks,
    required this.eyes,
    required this.scan,
    this.complete = false,
    this.completedSteps = 0,
    this.motionStep = -1,
  }) : super(repaint: Listenable.merge([animation, scan]));
  final Animation<double> scan;
  final bool complete;
  final int completedSteps;
  final int motionStep;
  final Animation<double> animation;
  final bool active;
  final List<Offset> landmarks;
  final List<Offset> eyes;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final oval = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * .72,
      height: size.height * .54,
    );
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(oval);
    canvas.drawPath(
      shade,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: .55),
            Colors.black.withValues(alpha: .65),
          ],
          radius: .9,
        ).createShader(Offset.zero & size),
    );
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = complete
          ? const Color(0xFF22C55E)
          : active
          ? _teal
          : Colors.white;
    final path = Path()..addOval(oval);
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 15) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 8, metric.length)),
          pen,
        );
      }
    }
    for (final corner in [
      oval.topLeft,
      oval.topRight,
      oval.bottomLeft,
      oval.bottomRight,
    ]) {
      final dx = corner.dx < oval.center.dx ? 1.0 : -1.0;
      final dy = corner.dy < oval.center.dy ? 1.0 : -1.0;
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx + dx * 22, corner.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx, corner.dy + dy * 22),
        pen..strokeWidth = 3,
      );
    }
    canvas.save();
    canvas.clipPath(Path()..addOval(oval));
    final beamY = BiometricLaser.paint(
      canvas,
      oval,
      scan.value,
      complete: complete,
    );
    canvas.restore();
    for (var side = 0; side < 2; side++) {
      final step = side + 1;
      final done = completedSteps > step;
      final focused = motionStep == step;
      final center = Offset(
        side == 0 ? oval.left - 13 : oval.right + 13,
        oval.center.dy,
      );
      final color = done
          ? const Color(0xFF22C55E)
          : focused
          ? _cyan
          : Colors.white38;
      final arrow = Path()
        ..moveTo(center.dx + (side == 0 ? 5 : -5), center.dy - 7)
        ..lineTo(center.dx + (side == 0 ? -3 : 3), center.dy)
        ..lineTo(center.dx + (side == 0 ? 5 : -5), center.dy + 7);
      canvas.drawPath(
        arrow,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: focused ? .5 + .5 * t : 1),
      );
      if (done) {
        final badge = center + const Offset(0, 20);
        canvas.drawCircle(badge, 7, Paint()..color = const Color(0xFF22C55E));
        canvas.drawPath(
          Path()
            ..moveTo(badge.dx - 3, badge.dy)
            ..lineTo(badge.dx - 1, badge.dy + 2)
            ..lineTo(badge.dx + 3, badge.dy - 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white,
        );
      }
    }
    if (!active && !complete) return;
    final hits = <Offset>[];
    void intersect(Offset a, Offset b) {
      if ((a.dy <= beamY && b.dy > beamY) || (b.dy <= beamY && a.dy > beamY)) {
        hits.add(
          Offset(a.dx + (b.dx - a.dx) * (beamY - a.dy) / (b.dy - a.dy), beamY),
        );
      }
    }

    Offset mapped(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    canvas.save();
    canvas.clipPath(Path()..addOval(oval));
    final meshPen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..shader = LinearGradient(
        colors: [
          (complete ? const Color(0xFF22C55E) : _cyan).withValues(
            alpha: complete ? .8 : .12 + .12 * t,
          ),
          (complete ? const Color(0xFF22C55E) : _teal).withValues(
            alpha: complete ? .8 : .35,
          ),
        ],
      ).createShader(oval);
    if (landmarks.length >= 4) {
      final anchors = landmarks.map(mapped).toList();
      final left = anchors.map((p) => p.dx).reduce(math.min);
      final right = anchors.map((p) => p.dx).reduce(math.max);
      final top = anchors.map((p) => p.dy).reduce(math.min);
      final bottom = anchors.map((p) => p.dy).reduce(math.max);
      final width = right - left;
      final height = bottom - top;
      // Curved lattice gives a dimensional HUD appearance. Its geometry is
      // interpolated from landmarks; it is not measured facial depth.
      Offset surface(double u, double v) {
        final taper = math.sqrt(math.max(0.0, 1 - v * v));
        return Offset(
          (left + right) / 2 + u * width * .68 * taper,
          top + height * .32 + v * height * .98 + u * u * height * .08,
        );
      }

      for (var line = -8; line <= 8; line++) {
        for (final vertical in [true, false]) {
          final wire = Path();
          Offset? previous;
          for (var sample = 0; sample <= 24; sample++) {
            final variable = -1 + sample / 12;
            final fixed = line / 9;
            final point = vertical
                ? surface(fixed, variable)
                : surface(variable, fixed);
            if (previous != null) intersect(previous, point);
            previous = point;
            if (sample == 0) {
              wire.moveTo(point.dx, point.dy);
            } else {
              wire.lineTo(point.dx, point.dy);
            }
          }
          canvas.drawPath(wire, meshPen);
        }
      }
    }
    // Subdivided curved connections between detected facial anchors.
    for (var i = 0; i < landmarks.length; i++) {
      for (var j = i + 1; j < landmarks.length; j++) {
        final a = mapped(landmarks[i]);
        final b = mapped(landmarks[j]);
        final mid = (a + b) / 2;
        final bend = Offset((b.dy - a.dy) * .08, (a.dx - b.dx) * .08);
        final control = mid + bend;
        var previous = a;
        for (var sample = 1; sample <= 12; sample++) {
          final u = sample / 12;
          final point =
              a * ((1 - u) * (1 - u)) +
              control * (2 * u * (1 - u)) +
              b * (u * u);
          intersect(previous, point);
          previous = point;
        }
        canvas.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..quadraticBezierTo(mid.dx + bend.dx, mid.dy + bend.dy, b.dx, b.dy),
          meshPen,
        );
        canvas.drawCircle(
          mid,
          1,
          Paint()
            ..color = (complete ? const Color(0xFF22C55E) : _cyan).withValues(
              alpha: .3,
            ),
        );
      }
    }
    for (final hit in hits) {
      canvas.drawCircle(
        hit,
        4,
        Paint()
          ..color = (complete ? const Color(0xFF22C55E) : _cyan).withValues(
            alpha: .45,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        hit,
        1.5,
        Paint()..color = complete ? const Color(0xFF22C55E) : _cyan,
      );
    }
    for (final node in landmarks) {
      final center = mapped(node);
      final intensity = complete
          ? 1.0
          : BiometricLaser.intersection(center.dy, beamY, oval.height * .055);
      final color = complete ? const Color(0xFF22C55E) : _cyan;
      canvas.drawCircle(
        center,
        3 + intensity * 3,
        Paint()
          ..color = color.withValues(alpha: .1 + .35 * intensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        center,
        1.5 + intensity * 1.5,
        Paint()..color = color.withValues(alpha: .25 + .75 * intensity),
      );
    }
    for (final eye in eyes) {
      final center = mapped(eye);
      final radius = size.width * .045;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = (complete ? const Color(0xFF22C55E) : _cyan).withValues(
            alpha: .18,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        center,
        radius,
        pen
          ..strokeWidth = 1.2
          ..color = (complete ? const Color(0xFF22C55E) : _teal).withValues(
            alpha: .8,
          ),
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + 5),
        t * math.pi * 2,
        math.pi * 1.3,
        false,
        pen
          ..color = (complete ? const Color(0xFF22C55E) : Colors.white)
              .withValues(alpha: .7),
      );
      canvas.drawCircle(
        center,
        2,
        Paint()..color = complete ? const Color(0xFF22C55E) : _cyan,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BiometricTrackingPainter oldDelegate) =>
      active != oldDelegate.active ||
      landmarks != oldDelegate.landmarks ||
      eyes != oldDelegate.eyes ||
      animation != oldDelegate.animation ||
      scan != oldDelegate.scan ||
      complete != oldDelegate.complete ||
      completedSteps != oldDelegate.completedSteps ||
      motionStep != oldDelegate.motionStep;
}

class BiometricCaptureActions extends StatelessWidget {
  const BiometricCaptureActions({
    super.key,
    required this.animation,
    required this.onCancel,
    required this.label,
  });
  final Animation<double> animation;
  final VoidCallback onCancel;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          SizedBox(
            width: 72,
            child: TextButton(
              onPressed: onCancel,
              child: const Text('Cancel', style: TextStyle(color: _teal)),
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) => Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A202C).withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: _cyan),
                  boxShadow: [
                    BoxShadow(
                      color: _cyan.withValues(
                        alpha: .12 + .16 * animation.value,
                      ),
                      blurRadius: 12 + 8 * animation.value,
                    ),
                  ],
                ),
                child: child,
              ),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 72),
        ],
      ),
      const SizedBox(height: 16),
      const Text(
        '© USTP Oroquieta',
        style: TextStyle(color: Colors.white54, fontSize: 11),
      ),
    ],
  );
}
