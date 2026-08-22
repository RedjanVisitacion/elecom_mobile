import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Login-screen–matched palette ─────────────────────────────────────────────
const Color _tNavy      = Color(0xFF0F1F3D);
const Color _tNavyLight = Color(0xFF1A2F55);
const Color _tGold      = Color(0xFFF59E0B);
const Color _tBgLight   = Color(0xFFF8FAFC);
const Color _tWhite     = Colors.white;
const Color _tMuted     = Color(0xFF64748B);
const Color _tBorder    = Color(0xFFCBD5E1);
// ─────────────────────────────────────────────────────────────────────────────

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _heading(String text) {
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
              color: _tGold.withValues(alpha: 0.12),
              border: Border.all(color: _tGold.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.verified_user_outlined, size: 15, color: _tGold),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: _tNavy,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paragraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          height: 1.62,
          color: _tMuted,
          fontWeight: FontWeight.w400,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 8),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: _tGold),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                height: 1.56,
                color: _tMuted,
                fontWeight: FontWeight.w400,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.requireAgreement,
      child: Scaffold(
        backgroundColor: _tBgLight,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: _tWhite,
          foregroundColor: _tNavy,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          title: Text(
            'Terms and Conditions',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              color: _tNavy,
              fontSize: 17,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(
              height: 1,
              thickness: 1,
              color: _tBorder.withValues(alpha: 0.7),
            ),
          ),
        ),
        body: ListView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 20, 16, widget.requireAgreement ? 16 : 24),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: BoxDecoration(
                color: _tWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _tBorder.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: _tNavy.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ECVS (ELECOM Voting System)',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      color: _tNavy,
                      fontSize: 15.5,
                      height: 1.22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Effective Date: April 25, 2026',
                    style: GoogleFonts.poppins(
                      color: _tMuted,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(color: _tBorder.withValues(alpha: 0.6), height: 1),

                  _heading('1. LEGAL AGREEMENT'),
                  _paragraph('These Terms and Conditions ("Terms") constitute a binding agreement between the user ("Student", "Voter", or "User") and the Electoral Commission (ELECOM) of the University of Science and Technology of Southern Philippines – Oroquieta Campus.'),
                  _paragraph('By accessing and using the ECVS mobile application, you confirm that you have read, understood, and agreed to comply with these Terms and all applicable laws and university policies.'),
                  _paragraph('If you do not agree, you must discontinue use of the application.'),

                  _heading('2. PURPOSE OF THE PLATFORM'),
                  _paragraph('The Electoral Commission Voting System (ECVS) is designed to:'),
                  _bullet('Facilitate secure student elections'),
                  _bullet('Provide access to candidate information'),
                  _bullet('Enable authorized users to cast votes'),
                  _bullet('Ensure accurate and automated vote counting'),
                  _bullet('Display official election results'),
                  _paragraph('The system is intended strictly for official campus election purposes.'),

                  _heading('3. ELIGIBILITY'),
                  _paragraph('To use the system, you must:'),
                  _bullet('Be an officially enrolled student of USTP Oroquieta Campus'),
                  _bullet('Possess a valid Student ID and registered account'),
                  _bullet('Be authorized by ELECOM to participate in the election'),
                  _paragraph('Each user is allowed one (1) vote per election.'),

                  _heading('4. USER RESPONSIBILITIES'),
                  _paragraph('Users agree to:'),
                  _bullet('Provide accurate and valid information'),
                  _bullet('Keep login credentials confidential'),
                  _bullet('Use the system only for legitimate voting purposes'),
                  _bullet('Follow election rules and guidelines set by ELECOM'),
                  _paragraph('Users must NOT:'),
                  _bullet('Attempt multiple voting'),
                  _bullet('Share or transfer account access'),
                  _bullet('Manipulate or interfere with the system'),
                  _bullet('Engage in fraudulent or malicious activities'),
                  _paragraph('Violation may result in account suspension and disciplinary action.'),

                  _heading('5. VOTING RULES AND SYSTEM USE'),
                  _bullet('Votes cast are final and cannot be changed'),
                  _bullet('Voting access is limited to authorized users only'),
                  _bullet('The system may restrict access based on network or security policies'),
                  _bullet('Election schedules are strictly enforced by ELECOM'),

                  _heading('6. DATA PRIVACY AND SECURITY'),
                  _paragraph('User data is collected and processed in accordance with the Data Privacy Act of 2012.'),
                  _paragraph('The system implements:'),
                  _bullet('Secure authentication mechanisms'),
                  _bullet('Encrypted data transmission'),
                  _bullet('Blockchain-based vote recording for integrity'),
                  _paragraph('Users agree that their data will be used solely for election-related purposes.'),

                  _heading('7. INTELLECTUAL PROPERTY'),
                  _paragraph('All components of the system, including:'),
                  _bullet('Software design'),
                  _bullet('Source code'),
                  _bullet('Database structures'),
                  _bullet('Interface design'),
                  _paragraph('are the property of the developers and the institution.'),
                  _paragraph('Unauthorized reproduction, modification, or distribution is strictly prohibited.'),

                  _heading('8. LIMITATION OF LIABILITY'),
                  _paragraph('The system is provided "as is" and "as available."'),
                  _paragraph('ELECOM and the developers shall not be liable for:'),
                  _bullet('System interruptions due to technical issues'),
                  _bullet('Delays caused by network or device limitations'),
                  _bullet('User errors during voting'),
                  _bullet('Unauthorized access beyond reasonable security controls'),

                  _heading('9. DATA BREACH AND INCIDENT RESPONSE'),
                  _paragraph('In the event of a security incident:'),
                  _bullet('Affected users will be notified promptly'),
                  _bullet('Necessary actions will be taken to secure the system'),
                  _bullet('Relevant authorities will be informed when required'),

                  _heading('10. GOVERNING LAW'),
                  _paragraph('These Terms shall be governed by the laws of the Republic of the Philippines.'),
                  _paragraph('Any disputes shall be subject to the jurisdiction of appropriate courts within the Philippines.'),

                  _heading('11. AMENDMENTS'),
                  _paragraph('ELECOM reserves the right to update these Terms at any time.'),
                  _paragraph('Continued use of the application constitutes acceptance of any changes.'),
                  const SizedBox(height: 8),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 520.ms)
            .slideY(begin: 0.03, end: 0, duration: 520.ms, curve: Curves.easeOutCubic),
          ],
        ),
        bottomNavigationBar: widget.requireAgreement
            ? Container(
                decoration: BoxDecoration(
                  color: _tWhite,
                  border: Border(
                    top: BorderSide(color: _tBorder.withValues(alpha: 0.7)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _tNavy.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      // Disagree
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _tNavyLight,
                            side: BorderSide(color: _tBorder, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Disagree',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _tNavyLight,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Agree
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFFACC15)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _tGold.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: _tNavy,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Agree',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: _tNavy,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
