import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _blue = Color(0xFF2563EB);
const Color _gold = Color(0xFFFACC15);
const Color _dark = Color(0xFF0F172A);
const Color _ink = Color(0xFF111827);

class ElecomTermsConditionsScreen extends StatefulWidget {
  const ElecomTermsConditionsScreen({super.key, this.requireAgreement = false});

  final bool requireAgreement;

  @override
  State<ElecomTermsConditionsScreen> createState() =>
      _ElecomTermsConditionsScreenState();
}

class _ElecomTermsConditionsScreenState
    extends State<ElecomTermsConditionsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasReachedBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!widget.requireAgreement ||
        !_scrollController.hasClients ||
        _hasReachedBottom) {
      return;
    }
    final position = _scrollController.position;
    final reachedBottom = position.pixels >= position.maxScrollExtent - 24;
    if (reachedBottom) {
      setState(() => _hasReachedBottom = true);
    }
  }

  Widget _heading(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(right: 9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.12),
              border: Border.all(color: _gold.withValues(alpha: 0.22)),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              size: 15,
              color: _gold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 15.0,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.95),
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paragraph(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          height: 1.62,
          color: Colors.white.withValues(alpha: 0.76),
          fontWeight: FontWeight.w400,
          fontSize: 12.9,
        ),
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SizedBox(
              width: 10,
              child: Text(
                '•',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _gold.withValues(alpha: 0.88),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                height: 1.56,
                color: Colors.white.withValues(alpha: 0.74),
                fontWeight: FontWeight.w400,
                fontSize: 12.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.requireAgreement,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFF05070B),
        appBar: AppBar(
          automaticallyImplyLeading: !widget.requireAgreement,
          backgroundColor: Colors.transparent,
          foregroundColor: _ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.58),
                      Colors.white.withValues(alpha: 0.14),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
          title: Text(
            'Terms and Conditions',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              color: _ink,
              fontSize: 17,
            ),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _TermsBackdrop(),
            SafeArea(
              child: ListView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  14,
                  22,
                  14,
                  widget.requireAgreement ? 112 : 18,
                ),
                children: [
                  _TermsGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ECVS (ELECOM Voting System)',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.96),
                            fontSize: 16.4,
                            height: 1.22,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Effective Date: April 25, 2026',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.76),
                            fontWeight: FontWeight.w500,
                            fontSize: 12.4,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _heading(context, '1. LEGAL AGREEMENT'),
                        _paragraph(
                          context,
                          'These Terms and Conditions (“Terms”) constitute a binding agreement between the user (“Student”, “Voter”, or “User”) and the Electoral Commission (ELECOM) of the University of Science and Technology of Southern Philippines – Oroquieta Campus.',
                        ),
                        _paragraph(
                          context,
                          'By accessing and using the ECVS mobile application, you confirm that you have read, understood, and agreed to comply with these Terms and all applicable laws and university policies.',
                        ),
                        _paragraph(
                          context,
                          'If you do not agree, you must discontinue use of the application.',
                        ),
                        _heading(context, '2. PURPOSE OF THE PLATFORM'),
                        _paragraph(
                          context,
                          'The Electoral Commission Voting System (ECVS) is designed to:',
                        ),
                        _bullet(context, 'Facilitate secure student elections'),
                        _bullet(
                          context,
                          'Provide access to candidate information',
                        ),
                        _bullet(
                          context,
                          'Enable authorized users to cast votes',
                        ),
                        _bullet(
                          context,
                          'Ensure accurate and automated vote counting',
                        ),
                        _bullet(context, 'Display official election results'),
                        _paragraph(
                          context,
                          'The system is intended strictly for official campus election purposes.',
                        ),
                        _heading(context, '3. ELIGIBILITY'),
                        _paragraph(context, 'To use the system, you must:'),
                        _bullet(
                          context,
                          'Be an officially enrolled student of USTP Oroquieta Campus',
                        ),
                        _bullet(
                          context,
                          'Possess a valid Student ID and registered account',
                        ),
                        _bullet(
                          context,
                          'Be authorized by ELECOM to participate in the election',
                        ),
                        _paragraph(
                          context,
                          'Each user is allowed one (1) vote per election.',
                        ),
                        _heading(context, '4. USER RESPONSIBILITIES'),
                        _paragraph(context, 'Users agree to:'),
                        _bullet(
                          context,
                          'Provide accurate and valid information',
                        ),
                        _bullet(context, 'Keep login credentials confidential'),
                        _bullet(
                          context,
                          'Use the system only for legitimate voting purposes',
                        ),
                        _bullet(
                          context,
                          'Follow election rules and guidelines set by ELECOM',
                        ),
                        _paragraph(context, 'Users must NOT:'),
                        _bullet(context, 'Attempt multiple voting'),
                        _bullet(context, 'Share or transfer account access'),
                        _bullet(
                          context,
                          'Manipulate or interfere with the system',
                        ),
                        _bullet(
                          context,
                          'Engage in fraudulent or malicious activities',
                        ),
                        _paragraph(
                          context,
                          'Violation may result in account suspension and disciplinary action.',
                        ),
                        _heading(context, '5. VOTING RULES AND SYSTEM USE'),
                        _bullet(
                          context,
                          'Votes cast are final and cannot be changed',
                        ),
                        _bullet(
                          context,
                          'Voting access is limited to authorized users only',
                        ),
                        _bullet(
                          context,
                          'The system may restrict access based on network or security policies',
                        ),
                        _bullet(
                          context,
                          'Election schedules are strictly enforced by ELECOM',
                        ),
                        _heading(context, '6. DATA PRIVACY AND SECURITY'),
                        _paragraph(
                          context,
                          'User data is collected and processed in accordance with the Data Privacy Act of 2012.',
                        ),
                        _paragraph(context, 'The system implements:'),
                        _bullet(context, 'Secure authentication mechanisms'),
                        _bullet(context, 'Encrypted data transmission'),
                        _bullet(
                          context,
                          'Blockchain-based vote recording for integrity',
                        ),
                        _paragraph(
                          context,
                          'Users agree that their data will be used solely for election-related purposes.',
                        ),
                        _heading(context, '7. INTELLECTUAL PROPERTY'),
                        _paragraph(
                          context,
                          'All components of the system, including:',
                        ),
                        _bullet(context, 'Software design'),
                        _bullet(context, 'Source code'),
                        _bullet(context, 'Database structures'),
                        _bullet(context, 'Interface design'),
                        _paragraph(
                          context,
                          'are the property of the developers and the institution.',
                        ),
                        _paragraph(
                          context,
                          'Unauthorized reproduction, modification, or distribution is strictly prohibited.',
                        ),
                        _heading(context, '8. LIMITATION OF LIABILITY'),
                        _paragraph(
                          context,
                          'The system is provided “as is” and “as available.”',
                        ),
                        _paragraph(
                          context,
                          'ELECOM and the developers shall not be liable for:',
                        ),
                        _bullet(
                          context,
                          'System interruptions due to technical issues',
                        ),
                        _bullet(
                          context,
                          'Delays caused by network or device limitations',
                        ),
                        _bullet(context, 'User errors during voting'),
                        _bullet(
                          context,
                          'Unauthorized access beyond reasonable security controls',
                        ),
                        _heading(
                          context,
                          '9. DATA BREACH AND INCIDENT RESPONSE',
                        ),
                        _paragraph(
                          context,
                          'In the event of a security incident:',
                        ),
                        _bullet(
                          context,
                          'Affected users will be notified promptly',
                        ),
                        _bullet(
                          context,
                          'Necessary actions will be taken to secure the system',
                        ),
                        _bullet(
                          context,
                          'Relevant authorities will be informed when required',
                        ),
                        _heading(context, '10. GOVERNING LAW'),
                        _paragraph(
                          context,
                          'These Terms shall be governed by the laws of the Republic of the Philippines.',
                        ),
                        _paragraph(
                          context,
                          'Any disputes shall be subject to the jurisdiction of appropriate courts within the Philippines.',
                        ),
                        _heading(context, '11. AMENDMENTS'),
                        _paragraph(
                          context,
                          'ELECOM reserves the right to update these Terms at any time.',
                        ),
                        _paragraph(
                          context,
                          'Continued use of the application constitutes acceptance of any changes.',
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.035, end: 0, duration: 620.ms, curve: Curves.easeOutCubic),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: widget.requireAgreement && _hasReachedBottom
            ? ClipRRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _dark.withValues(alpha: 0.84),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.36),
                              blurRadius: 28,
                              offset: const Offset(0, -12),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          minimum: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: _TermsActionButton(
                                  label: 'Disagree',
                                  outlined: true,
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _TermsActionButton(
                                  label: 'Agree',
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 420.ms)
                  .slideY(
                    begin: 0.12,
                    end: 0,
                    duration: 420.ms,
                    curve: Curves.easeOutCubic,
                  )
            : null,
      ),
    );
  }
}

class _TermsBackdrop extends StatelessWidget {
  const _TermsBackdrop();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 5600),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        final drift = math.sin(value * math.pi * 2);
        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFF7FAFF),
                    Color(0xFFE8EEF7),
                    Color(0xFF172033),
                    Color(0xFF05070B),
                  ],
                  stops: [0, 0.35, 0.49, 0.64, 1],
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(14 * drift, -6 * drift),
              child: const _TermsGlow(
                alignment: Alignment(0.84, -0.80),
                color: _blue,
                size: 260,
                alpha: 0.14,
              ),
            ),
            Transform.translate(
              offset: Offset(-10 * drift, 8 * drift),
              child: const _TermsGlow(
                alignment: Alignment(-0.92, -0.32),
                color: _gold,
                size: 210,
                alpha: 0.11,
              ),
            ),
            const Positioned.fill(child: _TermsPattern()),
            Positioned(
              top: 52,
              left: 0,
              right: 0,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 2.8, sigmaY: 2.8),
                child: Opacity(
                  opacity: 0.024,
                  child: Image.asset(
                    'assets/img_text/elecom_black.png',
                    height: 152,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TermsGlow extends StatelessWidget {
  const _TermsGlow({
    required this.alignment,
    required this.color,
    required this.size,
    required this.alpha,
  });

  final Alignment alignment;
  final Color color;
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 38, sigmaY: 38),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: alpha),
          ),
        ),
      ),
    );
  }
}

class _TermsGlassCard extends StatelessWidget {
  const _TermsGlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 25, 22, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: _dark.withValues(alpha: 0.86),
            border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.055),
                _dark.withValues(alpha: 0.86),
                Colors.black.withValues(alpha: 0.82),
              ],
              stops: const [0, 0.34, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: 34,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: _blue.withValues(alpha: 0.09),
                blurRadius: 34,
                offset: const Offset(-14, -12),
              ),
              BoxShadow(
                color: _gold.withValues(alpha: 0.055),
                blurRadius: 30,
                offset: const Offset(18, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TermsActionButton extends StatefulWidget {
  const _TermsActionButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  State<_TermsActionButton> createState() => _TermsActionButtonState();
}

class _TermsActionButtonState extends State<_TermsActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.972 : 1,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: widget.outlined
            ? OutlinedButton(
                onPressed: widget.onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  widget.label,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF020617), Color(0xFF111827), _gold],
                    stops: [0, 0.58, 1],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.42),
                      blurRadius: 20,
                      offset: const Offset(-8, 8),
                    ),
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(12, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: widget.onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    widget.label,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
      ),
    );
  }
}

class _TermsPattern extends StatelessWidget {
  const _TermsPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _TermsPatternPainter());
  }
}

class _TermsPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var x = 0.0; x <= size.width; x += 10) {
      for (var y = 28.0; y <= size.height; y += 10) {
        if ((x + y) % 30 == 0) {
          final top = y < size.height * 0.46;
          paint.color = (top ? _ink : Colors.white).withValues(
            alpha: top ? 0.075 : 0.052,
          );
          canvas.drawCircle(Offset(x, y), 0.7, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
