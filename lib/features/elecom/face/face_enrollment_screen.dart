import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/session/session_persistence.dart';
import '../../auth/presentation/login_screen.dart';
import '../data/elecom_mobile_api.dart';
import '../presentation/elecom_dashboard.dart';
import 'live_face_capture_screen.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({
    super.key,
    this.isMandatory = true,
    this.navigateToDashboardOnSuccess = true,
  });

  final bool isMandatory;
  final bool navigateToDashboardOnSuccess;

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  final ElecomMobileApi _api = ElecomMobileApi();

  static final Uri _supportMessengerUri =
      Uri.parse('https://m.me/redjan.phil.s.visitacion');
  static final Uri _supportEmailUri = Uri(
    scheme: 'mailto',
    path: 'rpsvcodes@gmail.com',
    queryParameters: <String, String>{
      'subject': 'ELECOM Support',
      'body': 'Hello, I need help with face enrollment.',
    },
  );

  bool _busy = false;
  String? _status; // null = hidden; shown only when there is something to say
  bool _uploadFailed = false;

  // ── Theme tokens ─────────────────────────────────────────────────────────
  static const Color _charcoal = Color(0xFF1C1C1E);
  static const Color _gold = Color(0xFFFEA501);
  static const Color _bg = Color(0xFFF4F4F6);
  static const Color _cardBg = Colors.white;
  static const Color _subtleGrey = Color(0xFF8E8E93);
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _captureFace() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _uploadFailed = false;
      _status = null;
    });
    try {
      final res = await Navigator.of(context).push<LiveFaceCaptureResult>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) =>
              const LiveFaceCaptureScreen(mode: LiveFaceMode.enrollment),
        ),
      );
      if (res == null) {
        if (mounted) setState(() => _status = 'Face capture cancelled.');
        return;
      }
      if (res.livenessPassed != true) {
        if (mounted) {
          setState(() =>
              _status = 'Liveness check did not complete. Please try again.');
        }
        return;
      }
      if (mounted) setState(() => _status = 'Uploading securely…');
      await _api.saveFaceEnrollment(capturedImageFile: res.capturedImage);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: const Text('Enrollment successful',
              style: TextStyle(fontWeight: FontWeight.w900)),
          content: const Text(
            'Your face reference was saved securely and is only used for voting verification.',
            style: TextStyle(fontWeight: FontWeight.w600, height: 1.35),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(
                  backgroundColor: _charcoal, foregroundColor: Colors.white),
              child: const Text('Continue',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (widget.navigateToDashboardOnSuccess) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ElecomDashboard()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } on ElecomApiException catch (e) {
      if (!mounted) return;
      final msg = ElecomMobileApi.isFaceAlreadyEnrolled(e)
          ? 'This face is already registered to another account. Please contact ELECOM.'
          : 'Enrollment could not be saved. ${e.message}';
      setState(() {
        _uploadFailed = true;
        _status = msg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadFailed = true;
        _status = 'Upload failed. Check your internet connection.';
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'You can log in again anytime. Enrollment will still be required before voting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _charcoal),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await SessionPersistence.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openMessengerSupport() async {
    try {
      final opened = await launchUrl(_supportMessengerUri,
          mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Unable to open Messenger support.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Unable to open Messenger support.')));
      }
    }
  }

  Future<void> _openEmailSupport() async {
    try {
      final opened = await launchUrl(_supportEmailUri,
          mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open email app.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open email app.')));
      }
    }
  }

  Future<void> _showSupportSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 10,
            right: 10,
            bottom: MediaQuery.of(ctx).padding.bottom + 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99)),
              ),
              const SizedBox(height: 14),
              const Text('Contact Support',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.black)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.facebook, color: Colors.blue),
                title: const Text('Facebook Messenger',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: Colors.black)),
                subtitle: const Text('Chat with support on Facebook',
                    style: TextStyle(color: Colors.black54)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _openMessengerSupport();
                },
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined,
                    color: Colors.black87),
                title: const Text('Email',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: Colors.black)),
                subtitle: const Text('rpsvcodes@gmail.com',
                    style: TextStyle(color: Colors.black54)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _openEmailSupport();
                },
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close',
                    style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final statusColor = _uploadFailed
        ? const Color(0xFFDC2626)
        : (_busy ? _charcoal : const Color(0xFF374151));

    return PopScope(
      canPop: !widget.isMandatory,
      child: Scaffold(
        backgroundColor: _bg,

        // ── Sticky AppBar — same style as StudentDashboard ───────────────
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: Colors.black12,
          centerTitle: false,
          titleSpacing: 0,
          automaticallyImplyLeading: !widget.isMandatory,
          title: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Opacity(
              opacity: 0.85,
              child: Image.asset(
                'assets/img_text/elecom_black1.png',
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'ELECOM',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: GestureDetector(
                onTap: _busy ? null : _logout,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout_rounded,
                        size: 17,
                        color: _busy ? Colors.black26 : _subtleGrey),
                    const SizedBox(width: 4),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _busy ? Colors.black26 : _subtleGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ── Body ────────────────────────────────────────────────────────
        body: Column(
          children: [
            // ── Scrollable content ──────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── Info card: charcoal + gold ─────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: _charcoal,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 14,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo + title row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border:
                                      Border.all(color: _gold, width: 2.5),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/elecom.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FACE VERIFICATION',
                                      style: TextStyle(
                                        color: _gold,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Enroll your voting face reference',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 12),

                          // Privacy note
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.shield_outlined,
                                  color: _gold, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your face reference will be used only to verify your identity during voting. It will not be shown publicly.',
                                  style: TextStyle(
                                    color: Colors.white
                                        .withValues(alpha: 0.72),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Face frame card ────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: const Color(0xFFE5E5EA)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0E000000),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 24),
                      child: Column(
                        children: [
                          // Oval face frame
                          Container(
                            width: 148,
                            height: 182,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              color: const Color(0xFFF0F0F5),
                              border: Border.all(
                                  color: const Color(0xFFD1D1D6),
                                  width: 1.5),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  top: 12,
                                  left: 18,
                                  child: _bracket(
                                      topLeft: true, color: _charcoal),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 18,
                                  child: _bracket(
                                      topRight: true, color: _charcoal),
                                ),
                                Positioned(
                                  bottom: 12,
                                  left: 18,
                                  child: _bracket(
                                      bottomLeft: true, color: _charcoal),
                                ),
                                Positioned(
                                  bottom: 12,
                                  right: 18,
                                  child: _bracket(
                                      bottomRight: true, color: _charcoal),
                                ),
                                const Icon(
                                  Icons.face_outlined,
                                  size: 64,
                                  color: Color(0xFFC7C7CC),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          const Text(
                            'Face Capture Area',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Center your face within the frame\nwhen the camera opens',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _subtleGrey,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom scroll breathing room
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── Pinned bottom area ──────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: _bg,
                border: const Border(
                  top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                18,
                12,
                18,
                bottomPadding > 0 ? bottomPadding + 8 : 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status message — only visible when set
                  if (_status != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _uploadFailed
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFE5E5EA),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (_busy)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _charcoal,
                              ),
                            )
                          else
                            Icon(
                              _uploadFailed
                                  ? Icons.error_outline_rounded
                                  : Icons.info_outline_rounded,
                              color: statusColor,
                              size: 17,
                            ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _status!,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: statusColor,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Primary CTA
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _captureFace,
                      icon: Icon(
                        _uploadFailed
                            ? Icons.refresh_rounded
                            : Icons.camera_alt_rounded,
                        size: 21,
                      ),
                      label: Text(
                        _uploadFailed
                            ? 'Retry upload'
                            : 'Start face enrollment',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _charcoal,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFFAAAAAA),
                        disabledForegroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Secondary — contact support
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _showSupportSheet,
                      icon: const Icon(Icons.support_agent_rounded,
                          size: 17),
                      label: const Text(
                        'Contact Support',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _subtleGrey,
                        side: const BorderSide(
                            color: Color(0xFFD1D1D6)),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bracket({
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
    required Color color,
  }) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(
        painter: _BracketPainter(
          color: color,
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter({
    required this.color,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  final Color color;
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    if (topLeft) {
      canvas.drawLine(Offset(0, h), Offset(0, 0), p);
      canvas.drawLine(Offset(0, 0), Offset(w, 0), p);
    }
    if (topRight) {
      canvas.drawLine(Offset(0, 0), Offset(w, 0), p);
      canvas.drawLine(Offset(w, 0), Offset(w, h), p);
    }
    if (bottomLeft) {
      canvas.drawLine(Offset(0, 0), Offset(0, h), p);
      canvas.drawLine(Offset(0, h), Offset(w, h), p);
    }
    if (bottomRight) {
      canvas.drawLine(Offset(w, 0), Offset(w, h), p);
      canvas.drawLine(Offset(0, h), Offset(w, h), p);
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) =>
      old.color != color ||
      old.topLeft != topLeft ||
      old.topRight != topRight ||
      old.bottomLeft != bottomLeft ||
      old.bottomRight != bottomRight;
}
