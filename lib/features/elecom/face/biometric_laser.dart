import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shared downward sweep. Fade at both ends hides the loop's position reset.
class BiometricLaser {
  static double progress(double phase) => Curves.easeInOut.transform(phase);
  static double intersection(double nodeY, double beamY, double radius) =>
      (1 - (nodeY - beamY).abs() / radius).clamp(0.0, 1.0);

  /// Caller clips this drawing to the face/guide path.
  static double paint(
    Canvas canvas,
    Rect bounds,
    double phase, {
    bool complete = false,
  }) {
    final y = complete
        ? bounds.bottom - 2
        : bounds.top + progress(phase) * bounds.height;
    final fade = complete
        ? 1.0
        : math.min(1.0, math.min(phase, 1 - phase) * 12);
    final color = complete ? const Color(0xFF22C55E) : const Color(0xFF00F0FF);
    final trail = Rect.fromLTRB(bounds.left, y - 20, bounds.right, y);
    if (!complete) {
      canvas.drawRect(
        trail,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0),
              color.withValues(alpha: .20 * fade),
            ],
          ).createShader(trail),
      );
    }
    final a = Offset(bounds.left, y);
    final b = Offset(bounds.right, y);
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color.withValues(alpha: .55 * fade)
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color.withValues(alpha: fade)
        ..strokeWidth = 2,
    );
    return y;
  }
}
