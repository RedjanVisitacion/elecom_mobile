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
              color: blue,
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
    required this.animate,
  });
  final double progress;
  final Color color;
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
    required this.shimmer,
    required this.animate,
  }) : super(repaint: shimmer);
  final Animation<double> shimmer;
  final bool animate;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final top = Path()..moveTo(0, size.height * 0.9);
    const peaks = <Offset>[
      Offset(0.10, 0.68),
      Offset(0.18, 0.78),
      Offset(0.32, 0.25),
      Offset(0.43, 0.55),
      Offset(0.57, 0.08),
      Offset(0.70, 0.48),
      Offset(0.79, 0.30),
      Offset(0.91, 0.72),
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
    canvas.drawPath(mountain, fill(0.22));
    canvas.drawPath(
      top,
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
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
    canvas.drawPath(mountain, fill(0.7));
    canvas.drawPath(
      top,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
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
          ..color = color
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_MountainProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.animate != animate;
}
