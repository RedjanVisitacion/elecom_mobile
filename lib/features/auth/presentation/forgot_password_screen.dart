import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/toast_service.dart';
import '../data/forgot_password_api.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared design tokens (match login screen)
// ─────────────────────────────────────────────────────────────────────────────

const Color _bg = Color(0xFFF5F5F5);
const Color _cardBg = Colors.white;
const Color _fieldBg = Color(0xFFE6E6E6);
const Color _hintColor = Color(0xFF9E9E9E);
const Color _black = Colors.black;
const Color _black54 = Colors.black54;

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
      final res =
          await _api.requestOtp(identifier: _identifierCtrl.text.trim());
      if (!mounted) return;
      AppToast.success(context, 'OTP sent successfully.');
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
            // Icon
            const Center(
              child: Icon(Icons.manage_accounts_outlined,
                  size: 56, color: _black),
            ),
            const SizedBox(height: 18),

            // Title
            const Text(
              'Find Your Account',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _black,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            const Text(
              'Enter your Student ID or registered email address to receive a one-time password.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: _black54,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),

            // Input
            _FpField(
              controller: _identifierCtrl,
              hintText: 'STUDENT ID OR EMAIL',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your Student ID or email.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Continue button
            _FpButton(
              label: 'CONTINUE',
              loading: _loading,
              onPressed: _continue,
            ),
            const SizedBox(height: 12),

            // Back to login
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
      AppToast.success(context, 'OTP resent successfully.');
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
      final res = await _api.verifyOtp(
        identifier: widget.identifier,
        otp: otp,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              ResetPasswordScreen(resetToken: res.resetToken),
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
          // Icon
          const Center(
            child: Icon(Icons.lock_outline_rounded, size: 56, color: _black),
          ),
          const SizedBox(height: 18),

          // Title
          const Text(
            'Enter OTP',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _black,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            widget.maskedEmail.isNotEmpty
                ? 'A 6-digit code was sent to ${widget.maskedEmail}. Enter it below.'
                : 'A 6-digit code was sent to your registered email. Enter it below.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: _black54,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),

          // OTP input — large centered digits
          _OtpField(controller: _otpCtrl),
          const SizedBox(height: 16),

          // Verify button
          _FpButton(
            label: 'VERIFY',
            loading: _loading,
            onPressed: _verify,
          ),
          const SizedBox(height: 14),

          // Resend row
          Center(
            child: GestureDetector(
              onTap: canResend ? _resend : null,
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _black54,
                  ),
                  children: [
                    const TextSpan(text: "Didn't receive it? "),
                    TextSpan(
                      text: canResend
                          ? 'Resend OTP'
                          : 'Resend in ${_secondsLeft}s',
                      style: TextStyle(
                        color: canResend ? _black : _black54,
                        fontWeight: FontWeight.w800,
                        decoration: canResend
                            ? TextDecoration.underline
                            : TextDecoration.none,
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
            // Icon
            const Center(
              child: Icon(Icons.lock_reset_rounded, size: 56, color: _black),
            ),
            const SizedBox(height: 18),

            // Title
            const Text(
              'Reset Password',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _black,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),

            const Text(
              'Create a new password for your account. Use at least 8 characters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: _black54,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),

            // New password
            _FpField(
              controller: _newPassCtrl,
              hintText: 'NEW PASSWORD',
              obscureText: _obscureNew,
              suffix: IconButton(
                onPressed: () =>
                    setState(() => _obscureNew = !_obscureNew),
                icon: Icon(
                  _obscureNew
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _black54,
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

            // Confirm password
            _FpField(
              controller: _confirmPassCtrl,
              hintText: 'CONFIRM PASSWORD',
              obscureText: _obscureConfirm,
              suffix: IconButton(
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _black54,
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
            const SizedBox(height: 16),

            // Reset button
            _FpButton(
              label: 'RESET PASSWORD',
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

/// Scaffold wrapper that applies the login-screen light theme and card layout.
class _FpScaffold extends StatelessWidget {
  const _FpScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.black,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: _bg,
    );

    return Theme(
      data: lightTheme,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: const BackButton(color: _black),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: _black,
              fontSize: 17,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 26),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFE0E0E0), width: 1),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded pill text field — matches the login screen's `_RoundedField`.
class _FpField extends StatelessWidget {
  const _FpField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
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
      style: const TextStyle(color: _black, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: _fieldBg,
        hintStyle: const TextStyle(
            color: _hintColor, fontWeight: FontWeight.w700),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Colors.black26),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}

/// Large centered OTP input — single field, digits only, max 6 chars.
class _OtpField extends StatelessWidget {
  const _OtpField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: _black,
        letterSpacing: 12,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '------',
        hintStyle: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: _black.withValues(alpha: 0.15),
          letterSpacing: 12,
        ),
        filled: true,
        fillColor: _fieldBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.black26),
        ),
      ),
    );
  }
}

/// Black pill primary button — matches the login screen's LOGIN button.
class _FpButton extends StatelessWidget {
  const _FpButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black38,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
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
        child: const Text(
          'Back to Login',
          style: TextStyle(
            color: _black54,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
