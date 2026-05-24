import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/toast_service.dart';
import '../data/forgot_password_api.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared design tokens (match login screen)
// ─────────────────────────────────────────────────────────────────────────────

const Color _blue = Color(0xFF2563EB);
const Color _gold = Color(0xFFFACC15);
const Color _dark = Color(0xFF0F172A);
const Color _muted = Color(0xFF94A3B8);
const Color _ink = Color(0xFF111827);

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Find Your Account
// ─────────────────────────────────────────────────────────────────────────────

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _api = ForgotPasswordApi();
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final res = await _api.requestOtp(
        identifier: _identifierCtrl.text.trim(),
      );
      if (!mounted) return;
      AppToast.success(context, 'OTP sent successfully.', isLoginScreen: true);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyOtpScreen(
            identifier: _identifierCtrl.text.trim(),
            maskedEmail: res.maskedEmail,
          ),
        ),
      );
    } on ForgotPasswordException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FpScaffold(
      title: 'Find Your Account',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FpHeaderIcon(icon: Icons.manage_accounts_outlined),
            const SizedBox(height: 16),

            Text(
              'Find Your Account',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Enter your Student ID or registered email to receive a verification code.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: _muted,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),

            _FpField(
              controller: _identifierCtrl,
              hintText: 'Student ID or Email',
              icon: Icons.person_search_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your Student ID or email.';
                }
                return null;
              },
            ),
            const SizedBox(height: 17),

            _FpButton(
              label: 'Continue',
              loading: _loading,
              onPressed: _continue,
            ),
            const SizedBox(height: 12),

            _BackToLoginButton(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Verify OTP
// ─────────────────────────────────────────────────────────────────────────────

class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({
    super.key,
    required this.identifier,
    required this.maskedEmail,
  });

  final String identifier;
  final String maskedEmail;

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _api = ForgotPasswordApi();
  final _otpCtrl = TextEditingController();
  bool _loading = false;

  // Resend cooldown — 60 seconds
  static const int _cooldownSeconds = 60;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) t.cancel();
      });
    });
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _loading) return;
    setState(() => _loading = true);
    try {
      await _api.requestOtp(identifier: widget.identifier);
      if (!mounted) return;
      AppToast.success(
        context,
        'OTP resent successfully.',
        isLoginScreen: true,
      );
      _startCooldown();
    } on ForgotPasswordException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, 'Could not resend OTP. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      AppToast.warning(context, 'Please enter the 6-digit OTP.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final res = await _api.verifyOtp(identifier: widget.identifier, otp: otp);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(resetToken: res.resetToken),
        ),
      );
    } on ForgotPasswordException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      if (msg.contains('expired')) {
        AppToast.error(context, 'OTP expired. Please request a new one.');
      } else if (msg.contains('invalid') || msg.contains('incorrect')) {
        AppToast.error(context, 'Invalid OTP code. Please try again.');
      } else {
        AppToast.error(context, e.message);
      }
      _otpCtrl.clear();
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft <= 0 && !_loading;

    return _FpScaffold(
      title: 'Enter OTP',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FpHeaderIcon(icon: Icons.lock_outline_rounded),
          const SizedBox(height: 16),

          Text(
            'Enter OTP',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            widget.maskedEmail.isNotEmpty
                ? 'A 6-digit code was sent to ${widget.maskedEmail}.'
                : 'A 6-digit code was sent to your registered email.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: _muted,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),

          // OTP input — large centered digits
          _OtpField(controller: _otpCtrl),
          const SizedBox(height: 17),

          // Verify button
          _FpButton(label: 'Verify', loading: _loading, onPressed: _verify),
          const SizedBox(height: 14),

          // Resend row
          Center(
            child: GestureDetector(
              onTap: canResend ? _resend : null,
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.66),
                  ),
                  children: [
                    const TextSpan(text: "Didn't receive it? "),
                    TextSpan(
                      text: canResend
                          ? 'Resend OTP'
                          : 'Resend in ${_secondsLeft}s',
                      style: TextStyle(
                        color: canResend ? _gold : _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          _BackToLoginButton(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Reset Password
// ─────────────────────────────────────────────────────────────────────────────

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.resetToken});

  final String resetToken;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _api = ForgotPasswordApi();
  final _formKey = GlobalKey<FormState>();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _loading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await _api.resetPassword(
        resetToken: widget.resetToken,
        newPassword: _newPassCtrl.text,
      );
      if (!mounted) return;
      AppToast.success(context, 'Password reset successfully.');
      // Pop all the forgot-password screens back to login
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ForgotPasswordException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FpScaffold(
      title: 'Reset Password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FpHeaderIcon(icon: Icons.lock_reset_rounded),
            const SizedBox(height: 16),

            Text(
              'Reset Password',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Create a new password for your account. Use at least 8 characters.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: _muted,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),

            _FpField(
              controller: _newPassCtrl,
              hintText: 'New Password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscureNew,
              suffix: IconButton(
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
                icon: Icon(
                  _obscureNew
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white.withValues(alpha: 0.58),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please enter a new password.';
                }
                if (v.length < 8) {
                  return 'Password must be at least 8 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            _FpField(
              controller: _confirmPassCtrl,
              hintText: 'Confirm Password',
              icon: Icons.verified_user_outlined,
              obscureText: _obscureConfirm,
              suffix: IconButton(
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white.withValues(alpha: 0.58),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please confirm your password.';
                }
                if (v != _newPassCtrl.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
            ),
            const SizedBox(height: 17),

            _FpButton(
              label: 'Reset Password',
              loading: _loading,
              onPressed: _reset,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FpScaffold extends StatelessWidget {
  const _FpScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _blue,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF050607),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFF050607),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              color: _ink,
              fontSize: 16,
            ),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _FpBackdrop(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 58, 24, 26),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child:
                        ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(
                                  sigmaX: 20,
                                  sigmaY: 20,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    24,
                                    20,
                                    18,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    color: _dark.withValues(alpha: 0.70),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.16,
                                      ),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.15),
                                        _dark.withValues(alpha: 0.68),
                                        Colors.black.withValues(alpha: 0.78),
                                      ],
                                      stops: const [0, 0.42, 1],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.42,
                                        ),
                                        blurRadius: 34,
                                        offset: const Offset(0, 20),
                                      ),
                                      BoxShadow(
                                        color: _blue.withValues(alpha: 0.18),
                                        blurRadius: 40,
                                        offset: const Offset(-14, -12),
                                      ),
                                      BoxShadow(
                                        color: _gold.withValues(alpha: 0.08),
                                        blurRadius: 34,
                                        offset: const Offset(18, 12),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      const Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter: _FpCardPatternPainter(),
                                          ),
                                        ),
                                      ),
                                      child,
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 520.ms, delay: 80.ms)
                            .slideY(
                              begin: 0.045,
                              end: 0,
                              duration: 620.ms,
                              curve: Curves.easeOutCubic,
                            ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded pill text field — matches the login screen's `_RoundedField`.
class _FpBackdrop extends StatelessWidget {
  const _FpBackdrop();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 5200),
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
                  stops: [0, 0.35, 0.49, 0.63, 1],
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(14 * drift, -6 * drift),
              child: const _FpGlow(
                alignment: Alignment(0.82, -0.82),
                color: _blue,
                size: 250,
                alpha: 0.22,
              ),
            ),
            Transform.translate(
              offset: Offset(-12 * drift, 8 * drift),
              child: const _FpGlow(
                alignment: Alignment(-0.92, -0.38),
                color: _gold,
                size: 210,
                alpha: 0.16,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _FpBackdropPainter(value)),
              ),
            ),
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 2.8, sigmaY: 2.8),
                child: Opacity(
                  opacity: 0.024,
                  child: Image.asset(
                    'assets/img_text/elecom_black.png',
                    height: 150,
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

class _FpGlow extends StatelessWidget {
  const _FpGlow({
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
        imageFilter: ui.ImageFilter.blur(sigmaX: 36, sigmaY: 36),
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

class _FpHeaderIcon extends StatelessWidget {
  const _FpHeaderIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: _blue.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: _gold, size: 30),
      ),
    );
  }
}

class _FpField extends StatelessWidget {
  const _FpField({
    required this.controller,
    required this.hintText,
    this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.052),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        cursorColor: _gold,
        style: GoogleFonts.poppins(
          color: Colors.white.withValues(alpha: 0.94),
          fontWeight: FontWeight.w600,
          fontSize: 13.4,
        ),
        decoration: InputDecoration(
          prefixIcon: icon == null
              ? null
              : Icon(icon, color: const Color(0xFF60A5FA), size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 46),
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            color: _muted.withValues(alpha: 0.72),
            fontWeight: FontWeight.w500,
            fontSize: 12.5,
          ),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 14, 11),
          suffixIcon: suffix,
          border: InputBorder.none,
          errorStyle: GoogleFonts.poppins(
            color: _gold,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            height: 0.7,
          ),
        ),
      ),
    );
  }
}

/// Large centered OTP input — single field, digits only, max 6 chars.
class _OtpField extends StatefulWidget {
  const _OtpField({required this.controller});

  final TextEditingController controller;

  @override
  State<_OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<_OtpField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _focusNode.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final activeIndex = math.min(text.length, 5);

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Stack(
        children: [
          Opacity(
            opacity: 0.01,
            child: TextFormField(
              focusNode: _focusNode,
              controller: widget.controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final filled = index < text.length;
              final active = _focusNode.hasFocus && index == activeIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 38,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withValues(alpha: active ? 0.075 : 0.052),
                  border: Border.all(
                    color: active
                        ? _gold.withValues(alpha: 0.78)
                        : Colors.white.withValues(alpha: 0.14),
                    width: active ? 1.35 : 1,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: _gold.withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ]
                      : null,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  child: Text(
                    filled ? text[index] : '',
                    key: ValueKey('$index-${filled ? text[index] : ''}'),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Black pill primary button — matches the login screen's LOGIN button.
class _FpButton extends StatefulWidget {
  const _FpButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool loading;

  @override
  State<_FpButton> createState() => _FpButtonState();
}

class _FpButtonState extends State<_FpButton> {
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.50),
                blurRadius: 22,
                offset: const Offset(-8, 10),
              ),
              BoxShadow(
                color: _gold.withValues(alpha: 0.24),
                blurRadius: 26,
                offset: const Offset(18, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF020617), Color(0xFF111827), _gold],
                        stops: [0, 0.58, 1],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: widget.loading ? null : widget.onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    child: widget.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            widget.label,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Back to Login" text button — pops all forgot-password screens.
class _BackToLoginButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF60A5FA).withValues(alpha: 0.92),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          'Back to Login',
          style: GoogleFonts.poppins(
            color: const Color(0xFF60A5FA).withValues(alpha: 0.92),
            fontWeight: FontWeight.w700,
            fontSize: 12.4,
          ),
        ),
      ),
    );
  }
}

class _FpBackdropPainter extends CustomPainter {
  const _FpBackdropPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint();
    for (var x = 0.0; x <= size.width; x += 10) {
      for (var y = 30.0; y <= size.height; y += 10) {
        final top = y < size.height * 0.45;
        if ((x + y) % 30 == 0) {
          dotPaint.color = (top ? _ink : Colors.white).withValues(
            alpha: top ? 0.08 : 0.055,
          );
          canvas.drawCircle(Offset(x, y), 0.7, dotPaint);
        }
      }
    }

    final streakPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.05, size.height * 0.20),
        Offset(size.width * 0.86, size.height * 0.34),
        [
          Colors.white.withValues(alpha: 0),
          _blue.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0),
        ],
        [0, 0.5, 1],
      )
      ..strokeWidth = 1.1
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final drift = math.sin(progress * math.pi * 2);
    canvas.drawLine(
      Offset(-20 + drift * 8, size.height * 0.31),
      Offset(size.width + 20, size.height * 0.18 + drift * 6),
      streakPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FpBackdropPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _FpCardPatternPainter extends CustomPainter {
  const _FpCardPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var x = 8.0; x <= size.width; x += 14) {
      for (var y = size.height * 0.58; y <= size.height - 4; y += 14) {
        paint.color = Colors.white.withValues(alpha: 0.055);
        canvas.drawCircle(Offset(x, y), 0.85, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
