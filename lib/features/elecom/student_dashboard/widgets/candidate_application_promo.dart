import 'dart:async';

import 'package:flutter/material.dart';

class CandidateApplicationPromo extends StatefulWidget {
  const CandidateApplicationPromo({
    super.key,
    required this.isDarkMode,
    required this.onApplyNow,
    this.isPremiumMode = false,
  });

  final bool isDarkMode;
  final bool isPremiumMode;
  final VoidCallback onApplyNow;

  @override
  State<CandidateApplicationPromo> createState() =>
      _CandidateApplicationPromoState();
}

class _CandidateApplicationPromoState extends State<CandidateApplicationPromo> {
  static const List<String> _slides = [
    'assets/candidates_model/00. The Team.png',
    'assets/candidates_model/01. Redjan.png',
    'assets/candidates_model/02. Lollaine.png',
    'assets/candidates_model/03. Von.png',
    'assets/candidates_model/04. Kurt.png',
  ];

  final PageController _controller = PageController();
  Timer? _autoScrollTimer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shadowColor = widget.isPremiumMode
        ? const Color(0xFF2563EB).withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: widget.isDarkMode ? 0.32 : 0.12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 2.22,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: PageView.builder(
                controller: _controller,
                physics: const BouncingScrollPhysics(),
                itemCount: _slides.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  return _CandidateApplicationSlide(
                    assetPath: _slides[index],
                    onApplyNow: widget.onApplyNow,
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF94A3B8).withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _CandidateApplicationSlide extends StatelessWidget {
  const _CandidateApplicationSlide({
    required this.assetPath,
    required this.onApplyNow,
  });

  final String assetPath;
  final VoidCallback onApplyNow;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF08265F), Color(0xFFF6B62D)],
                ),
              ),
            );
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xCC031A4B),
                Color(0x990B3276),
                Color(0x220B3276),
                Color(0x000B3276),
              ],
              stops: [0, 0.46, 0.72, 1],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 14, 12),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 0.58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ready to Lead?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 23,
                    height: 1.02,
                    shadows: [
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Register as a candidate. ELECOM will verify eligibility.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    height: 1.18,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 36,
                  child: FilledButton.icon(
                    onPressed: onApplyNow,
                    icon: const Icon(Icons.how_to_reg_rounded, size: 17),
                    label: const Text('File now'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0C2C66),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
