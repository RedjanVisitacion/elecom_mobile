import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/toast_service.dart';
import '../data/forgot_password_api.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — light palette matching login screen
// ─────────────────────────────────────────────────────────────────────────────

const Color _fpBgLight   = Color(0xFFF8FAFC);
const Color _fpNavy      = Color(0xFF0F1F3D);
const Color _fpNavyLight = Color(0xFF1A2F55);
const Color _fpGold      = Color(0xFFF59E0B);
const Color _fpGoldLight = Color(0xFFFACC15);
const Color _fpWhite     = Colors.white;
const Color _fpMuted     = Color(0xFF64748B);
const Color _fpBorder    = Color(0xFFCBD5E1);
const Color _fpError     = Color(0xFFDC2626);

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
  String _channel = 'email'; // 'email' or 'sms'

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
        channel: _channel,
      );
      if (!mounted) return;
      final sentTo = _channel == 'sms'
          ? res.maskedPhone.isNotEmpty
              ? res.maskedPhone
              : 'your phone'
          : res.maskedEmail.isNotEmpty
              ? res.maskedEmail
              : 'your email';
      AppToast.success(
        context,
        'OTP sent to $sentTo.',
        isLoginScreen: true,
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyOtpScreen(
            identifier: _identifierCtrl.text.trim(),
            maskedContact: sentTo,
            channel: _channel,
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
                color: _fpNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your Student ID or registered email, then choose how to receive your verification code.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: _fpMuted,
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
            const SizedBox(height: 20),
            // ── Channel selector ──────────────────────────────────────────
            Text(
              'Send OTP via',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _fpMuted,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ChannelOption(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    selected: _channel == 'email',
                    onTap: () => setState(() => _channel = 'email'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ChannelOption(
                    icon: Icons.sms_outlined,
                    label: 'SMS',
                    selected: _channel == 'sms',
                    onTap: () => setState(() => _channel = 'sms'),
                  ),
                ),
              ],
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
    required this.maskedContact,
    this.channel = 'email',
  });

  final String identifier;
  final String maskedContact;
  final String channel;

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _api = ForgotPasswordApi();
  final _otpCtrl = TextEditingController();
  bool _loading = false;

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
      if (!mounted) { t.cancel(); return; }
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
      await _api.requestOtp(
        identifier: widget.identifier,
        channel: widget.channel,
      );
      if (!mounted) return;
      AppToast.success(context, 'OTP resent successfully.', isLoginScreen: true);
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
              color: _fpNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.maskedContact.isNotEmpty
                ? 'A 6-digit code was sent to ${widget.maskedContact}.'
                : widget.channel == 'sms'
                    ? 'A 6-digit code was sent to your phone.'
                    : 'A 6-digit code was sent to your registered email.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: _fpMuted,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          _OtpField(controller: _otpCtrl),
          const SizedBox(height: 17),
          _FpButton(label: 'Verify', loading: _loading, onPressed: _verify),
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTap: canResend ? _resend : null,
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w500,
                    color: _fpMuted,
                  ),
                  children: [
                    const TextSpan(text: "Didn't receive it? "),
                    TextSpan(
                      text: canResend
                          ? 'Resend OTP'
                          : 'Resend in ${_secondsLeft}s',
                      style: TextStyle(
                        color: canResend ? _fpGold : _fpMuted,
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
                color: _fpNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new password for your account. Use at least 8 characters.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: _fpMuted,
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
                  color: _fpMuted,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter a new password.';
                if (v.length < 8) return 'Password must be at least 8 characters.';
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
                  color: _fpMuted,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please confirm your password.';
                if (v != _newPassCtrl.text) return 'Passwords do not match.';
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
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: _fpBgLight,
      ),
      child: Scaffold(
        backgroundColor: _fpBgLight,
        appBar: AppBar(
          backgroundColor: _fpWhite,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: _fpNavy),
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              color: _fpNavy,
              fontSize: 16,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: _fpBorder),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  child: child,
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
      ),
    );
  }
}

// ── Header icon ───────────────────────────────────────────────────────────────

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
          color: _fpGold.withValues(alpha: 0.12),
          border: Border.all(color: _fpGold.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: _fpGold, size: 30),
      ),
    );
  }
}

// ── Underline text field (matches login _WebInputField) ───────────────────────

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
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      cursorColor: _fpGold,
      style: GoogleFonts.poppins(
        color: _fpNavy,
        fontWeight: FontWeight.w500,
        fontSize: 13.4,
      ),
      decoration: InputDecoration(
        prefixIcon: icon == null
            ? null
            : Icon(icon, color: _fpGold, size: 18),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 40),
        hintText: hintText,
        filled: false,
        hintStyle: GoogleFonts.poppins(
          color: _fpMuted.withValues(alpha: 0.65),
          fontWeight: FontWeight.w400,
          fontSize: 12.5,
        ),
        contentPadding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
        suffixIcon: suffix,
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _fpBorder, width: 1.2),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _fpGold, width: 1.8),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _fpError, width: 1.2),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _fpError, width: 1.8),
        ),
        errorStyle: GoogleFonts.poppins(
          color: _fpError,
          fontWeight: FontWeight.w600,
          fontSize: 10,
          height: 1.2,
        ),
      ),
    );
  }
}

// ── OTP field ────────────────────────────────────────────────────────────────

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
                  color: active
                      ? _fpGold.withValues(alpha: 0.06)
                      : _fpWhite,
                  border: Border.all(
                    color: active ? _fpGold : _fpBorder,
                    width: active ? 1.35 : 1,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: _fpGold.withValues(alpha: 0.22),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
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
                      color: _fpNavy,
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

// ── Gold gradient primary button (matches login Sign In button) ───────────────

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
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [_fpGold, _fpGoldLight, _fpGold],
              stops: [0, 0.5, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: _fpGold.withValues(alpha: 0.38),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: widget.loading ? null : widget.onPressed,
              child: SizedBox(
                height: 52,
                child: Center(
                  child: widget.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(_fpNavy),
                          ),
                        )
                      : Text(
                          widget.label,
                          style: GoogleFonts.poppins(
                            color: _fpNavy,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Back to Login button (matches "Forgot Password?" link in login) ───────────

class _BackToLoginButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Back to Login',
          style: GoogleFonts.poppins(
            color: _fpNavyLight,
            fontWeight: FontWeight.w700,
            fontSize: 12.4,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ── Channel selector option card ──────────────────────────────────────────────

class _ChannelOption extends StatelessWidget {
  const _ChannelOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? _fpGold.withValues(alpha: 0.10)
              : _fpWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _fpGold : _fpBorder,
            width: selected ? 1.6 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _fpGold.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? _fpGold : _fpMuted,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? _fpNavy : _fpMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
