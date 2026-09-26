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
  static const List<_CandidatePromoSlide> _slides = [
    _CandidatePromoSlide(
      assetPath: 'assets/candidates_model/00. The Team.png',
      title: 'Lead the Change',
      subtitle: 'File your candidacy and let ELECOM check your eligibility.',
    ),
    _CandidatePromoSlide(
      assetPath: 'assets/candidates_model/01. Redjan.png',
      title: 'Your Voice, Your Run',
      subtitle: 'Step forward for your organization and start your filing.',
    ),
    _CandidatePromoSlide(
      assetPath: 'assets/candidates_model/02. Lollaine.png',
      title: 'Ready to Serve?',
      subtitle: 'Submit your details and campaign platform for review.',
    ),
    _CandidatePromoSlide(
      assetPath: 'assets/candidates_model/03. Von.png',
      title: 'Be on the Ballot',
      subtitle: 'ELECOM will verify your requirements before publishing.',
    ),
    _CandidatePromoSlide(
      assetPath: 'assets/candidates_model/04. Kurt.png',
      title: 'Make It Official',
      subtitle: 'Complete your filing and wait for ELECOM approval.',
    ),
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
                    slide: _slides[index],
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
    required this.slide,
    required this.onApplyNow,
  });

  final _CandidatePromoSlide slide;
  final VoidCallback onApplyNow;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          slide.assetPath,
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
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 0.52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slide.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.2,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slide.subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w400,
                        fontSize: 10,
                        height: 1.35,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: FilledButton.icon(
                    onPressed: onApplyNow,
                    icon: const Icon(Icons.how_to_reg_rounded, size: 14),
                    label: const Text('File now'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0C2C66),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        letterSpacing: 0.1,
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

class _CandidatePromoSlide {
  const _CandidatePromoSlide({
    required this.assetPath,
    required this.title,
    required this.subtitle,
  });

  final String assetPath;
  final String title;
  final String subtitle;
}
