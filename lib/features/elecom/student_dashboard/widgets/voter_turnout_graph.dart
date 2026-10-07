import 'package:flutter/material.dart';

/// A decorative mountain silhouette filled by the actual turnout fraction.
/// The peaks represent a progress shape, not historical voting measurements.
class VoterTurnoutGraph extends StatelessWidget {
  const VoterTurnoutGraph({
    super.key,
    required this.voters,
    required this.castVotes,
    required this.isDark,
    this.animate = true,
  });

  final int voters;
  final int? castVotes;
  final bool isDark;
  final bool animate;

  String _count(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );

  @override
  Widget build(BuildContext context) {
    final blue = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final ink = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569);
    final available = castVotes != null && voters > 0;
    final percentage = available ? 100 * castVotes! / voters : null;
    return Semantics(
      label: available
          ? 'Voter turnout ${percentage!.toStringAsFixed(1)} percent. $castVotes of $voters voted.'
          : 'Voter turnout unavailable',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Voter Turnout',
                  style: TextStyle(
                    color: ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                percentage == null ? '—' : '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: blue,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Text(
            available
                ? '${_count(castVotes!)} voted • ${_count(voters)} total voters'
                : 'Turnout unavailable',
            style: TextStyle(color: ink, fontSize: 10),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _AnimatedMountain(
              progress: available ? (castVotes! / voters).clamp(0.0, 1.0) : 0,
              color: isDark ? const Color(0xFFFACC15) : const Color(0xFFD9A514),
              progressColor: blue,
              animate: animate,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('0%', style: TextStyle(color: ink, fontSize: 9)),
              Expanded(
                child: Text(
                  'Turnout progress',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ink, fontSize: 9),
                ),
              ),
              Text('100%', style: TextStyle(color: ink, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedMountain extends StatefulWidget {
  const _AnimatedMountain({
    required this.progress,
    required this.color,
    required this.progressColor,
    required this.animate,
  });
  final double progress;
  final Color color;
  final Color progressColor;
  final bool animate;

  @override
  State<_AnimatedMountain> createState() => _AnimatedMountainState();
}

class _AnimatedMountainState extends State<_AnimatedMountain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  bool _reduceMotion = false;

  void _syncAnimation() {
    if (widget.animate && !_reduceMotion && TickerMode.of(context)) {
      if (!_shimmer.isAnimating) _shimmer.repeat();
    } else {
      _shimmer.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _AnimatedMountain oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: widget.progress),
        duration: _reduceMotion || !widget.animate
            ? Duration.zero
            : const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) => CustomPaint(
          painter: _MountainProgressPainter(
            progress: progress,
            color: widget.color,
            progressColor: widget.progressColor,
            shimmer: _shimmer,
            animate: widget.animate && !_reduceMotion,
          ),
        ),
      ),
    );
  }
}

class _MountainProgressPainter extends CustomPainter {
  _MountainProgressPainter({
    required this.progress,
    required this.color,
    required this.progressColor,
    required this.shimmer,
    required this.animate,
  }) : super(repaint: shimmer);
  final Animation<double> shimmer;
  final bool animate;
  final double progress;
  final Color color;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final top = Path()..moveTo(0, size.height * 0.9);
    const peaks = <Offset>[
      Offset(0.07, 0.76),
      Offset(0.11, 0.64),
      Offset(0.16, 0.72),
      Offset(0.20, 0.59),
      Offset(0.24, 0.44),
      Offset(0.28, 0.38),
      Offset(0.32, 0.23),
      Offset(0.36, 0.35),
      Offset(0.39, 0.40),
      Offset(0.44, 0.56),
      Offset(0.49, 0.34),
      Offset(0.53, 0.26),
      Offset(0.57, 0.10),
      Offset(0.61, 0.24),
      Offset(0.64, 0.28),
      Offset(0.69, 0.48),
      Offset(0.74, 0.38),
      Offset(0.79, 0.30),
      Offset(0.83, 0.43),
      Offset(0.86, 0.49),
      Offset(0.90, 0.68),
      Offset(0.96, 0.82),
      Offset(1, 0.9),
    ];
    for (final peak in peaks) {
      top.lineTo(size.width * peak.dx, size.height * peak.dy);
    }
    final mountain = Path.from(top)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    Paint fill(double opacity) => Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: opacity * 0.2),
        ],
      ).createShader(Offset.zero & size);
    Offset point(double x, double y) => Offset(size.width * x, size.height * y);
    Path polygon(List<Offset> vertices) {
      final path = Path()..moveTo(vertices.first.dx, vertices.first.dy);
      for (final vertex in vertices.skip(1)) {
        path.lineTo(vertex.dx, vertex.dy);
      }
      return path..close();
    }

    // A distant ridge gives depth without competing with the progress scale.
    final distant = polygon([
      point(0, 1),
      point(0.12, 0.83),
      point(0.22, 0.33),
      point(0.29, 0.53),
      point(0.39, 0.16),
      point(0.48, 0.44),
      point(0.65, 0.22),
      point(0.74, 0.57),
      point(0.85, 0.39),
      point(1, 0.89),
      point(1, 1),
    ]);
    canvas.drawPath(distant, fill(0.12));
    canvas.drawPath(mountain, fill(0.28));
    canvas.save();
    canvas.clipPath(mountain);
    // Asymmetric shaded slopes distinguish the major summits.
    for (final face in [
      [
        point(0.32, 0.23),
        point(0.36, 0.65),
        point(0.47, 0.95),
        point(0.44, 0.56),
      ],
      [
        point(0.57, 0.10),
        point(0.61, 0.53),
        point(0.72, 0.95),
        point(0.69, 0.48),
      ],
      [
        point(0.79, 0.30),
        point(0.82, 0.67),
        point(0.96, 0.95),
        point(0.90, 0.68),
      ],
    ]) {
      canvas.drawPath(polygon(face), fill(0.23));
    }
    final ridgePaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeJoin = StrokeJoin.round;
    for (final ridge in [
      [
        point(0.32, 0.23),
        point(0.30, 0.49),
        point(0.34, 0.65),
        point(0.28, 0.83),
      ],
      [
        point(0.57, 0.10),
        point(0.54, 0.42),
        point(0.58, 0.58),
        point(0.51, 0.85),
      ],
      [
        point(0.79, 0.30),
        point(0.77, 0.53),
        point(0.80, 0.70),
        point(0.75, 0.87),
      ],
    ]) {
      final path = Path()..moveTo(ridge.first.dx, ridge.first.dy);
      for (final vertex in ridge.skip(1)) {
        path.lineTo(vertex.dx, vertex.dy);
      }
      canvas.drawPath(path, ridgePaint);
    }
    // Fine foothill contours keep detail legible at this compact height.
    for (var i = 0; i < 3; i++) {
      final y = 0.78 + i * 0.07;
      final contour = Path()
        ..moveTo(0, size.height * y)
        ..quadraticBezierTo(
          size.width * 0.18,
          size.height * (y - 0.12),
          size.width * 0.34,
          size.height * y,
        )
        ..quadraticBezierTo(
          size.width * 0.52,
          size.height * (y - 0.13),
          size.width * 0.70,
          size.height * y,
        )
        ..quadraticBezierTo(
          size.width * 0.85,
          size.height * (y - 0.07),
          size.width,
          size.height * (y + 0.03),
        );
      canvas.drawPath(
        contour,
        Paint()
          ..color = color.withValues(alpha: 0.13)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }
    canvas.restore();
    canvas.drawPath(
      top,
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeJoin = StrokeJoin.round,
    );
    if (animate) {
      // Decorative light sweep; the turnout boundary remains tied to real data.
      final sweepX = size.width * (shimmer.value * 1.6 - 0.3);
      final sweepWidth = size.width * 0.22;
      canvas.save();
      canvas.clipPath(mountain);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader =
              LinearGradient(
                colors: [
                  color.withValues(alpha: 0),
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0),
                ],
                stops: const [0, 0.5, 1],
              ).createShader(
                Rect.fromLTWH(
                  sweepX - sweepWidth,
                  0,
                  sweepWidth * 2,
                  size.height,
                ),
              ),
      );
      canvas.restore();
    }
    // Only this filled portion encodes turnout; never invent peaks from data.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    canvas.drawPath(
      mountain,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            progressColor.withValues(alpha: 0.65),
            progressColor.withValues(alpha: 0.2),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      top,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..strokeWidth = 2,
    );
    if (progress > 0) {
      canvas.drawLine(
        Offset(0, size.height - 1),
        Offset(size.width * progress, size.height - 1),
        Paint()
          ..color = progressColor
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_MountainProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.animate != animate;
}
