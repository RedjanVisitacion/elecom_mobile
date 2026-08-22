import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/notifications/notification_center_store.dart';
import '../../../core/utils/toast_service.dart';
import '../../../services/tutorial_service.dart';
import '../../elecom/data/elecom_mobile_api.dart';
import '../../elecom/face/face_enrollment_screen.dart';
import '../../elecom/presentation/elecom_dashboard.dart';
import '../../elecom/profile/elecom_terms_conditions_screen.dart';
import '../presentation/forgot_password_screen.dart';
import '../state/login_view_model.dart';

// ─── Web-matched color palette ────────────────────────────────────────────────
const _kNavy = Color(0xFF0F1F3D);
const _kNavyLight = Color(0xFF1A2F55);
const _kGold = Color(0xFFF59E0B);
const _kGoldLight = Color(0xFFFACC15);
const _kWhite = Colors.white;
const _kBgLight = Color(0xFFF8FAFC);
const _kTextDark = Color(0xFF0F1F3D);
const _kTextMuted = Color(0xFF64748B);
const _kBorder = Color(0xFFCBD5E1);
// ──────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AnimationController _shimmerController;
  bool _buttonPressed = false;
  bool _loginTutorialScheduled = false;
  Timer? _validationTimer;

  final ElecomMobileApi _mobileApi = ElecomMobileApi();

  Future<void> _submit() async {
    final vm = context.read<LoginViewModel>();
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) {
      // Auto-clear validation errors after 3 seconds
      _validationTimer?.cancel();
      _validationTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) _formKey.currentState?.reset();
      });
      return;
    }

    if (!vm.acceptedTerms) {
      AppToast.warning(
        context,
        'Please accept the Terms & Conditions.',
        isLoginScreen: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    try {
      await vm.login(
        studentId: _studentIdController.text.trim(),
        password: _passwordController.text,
      );
      await NotificationCenterStore.init(forceRefresh: true);
      final enrollment = await _mobileApi.getFaceEnrollmentStatus();
      final isEnrolled = enrollment['enrolled'] == true;

      if (!mounted) return;
      AppToast.dismissAll();
      TutorialService.dismissActiveTutorial();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => isEnrolled
              ? const ElecomDashboard()
              : const FaceEnrollmentScreen(isMandatory: true),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      final msg = vm.error ?? 'Login failed';
      AppToast.error(context, msg, isLoginScreen: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeStartLoginTutorial(),
    );
  }

  Future<void> _maybeStartLoginTutorial() async {
    if (!mounted || _loginTutorialScheduled) return;
    if (!await TutorialPrefs.shouldShowLoginTutorial()) return;
    _loginTutorialScheduled = true;
    if (!mounted) return;
    await TutorialService.showLoginTutorialIfNeeded(context: context);
  }

  @override
  void dispose() {
    _validationTimer?.cancel();
    _shimmerController.dispose();
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: _kBgLight,
        checkboxTheme: const CheckboxThemeData(
          checkColor: WidgetStatePropertyAll<Color>(_kWhite),
        ),
      ),
      child: Scaffold(
        backgroundColor: _kBgLight,
        // resizeToAvoidBottomInset pushes the whole body up when keyboard opens
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _WebBackdrop(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  final compact = h < 680;
                  final hPad = (w * 0.07).clamp(20.0, 32.0);
                  final topPad = compact ? 56.0 : h * 0.13;
                  final fieldH = compact ? 46.0 : 50.0;
                  final btnH = compact ? 48.0 : 52.0;
                  final fs = compact ? 13.0 : 14.0;

                  // Outer Column: scrollable content + pinned footer
                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, 16.0),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Form(
                                key: _formKey,
                                child: _WebFormCard(
                                  compact: compact,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // ── Logo with glow ──
                                      FadeIn(
                                        duration: const Duration(milliseconds: 600),
                                        child: Center(
                                          child: Image.asset(
                                            'assets/USTP_ELECOM_ICON_NOBG.png',
                                            width: compact ? 120.0 : 136.0,
                                            height: compact ? 120.0 : 136.0,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: compact ? 0.0 : 2.0),

                                      // Student ID field
                                      SlideInUp(
                                        duration: const Duration(milliseconds: 520),
                                        delay: const Duration(milliseconds: 80),
                                        from: 14,
                                        child: _WebInputField(
                                          key: ElecomTutorialKeys.loginStudentId,
                                          controller: _studentIdController,
                                          hintText: 'Enter your student ID',
                                          icon: Icons.badge_outlined,
                                          height: fieldH,
                                          fontSize: fs,
                                          keyboardType: TextInputType.text,
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) {
                                              return 'Please enter your student ID';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      SizedBox(height: compact ? 12.0 : 14.0),

                                      // Password field
                                      SlideInUp(
                                        duration: const Duration(milliseconds: 540),
                                        delay: const Duration(milliseconds: 140),
                                        from: 14,
                                        child: _WebInputField(
                                          key: ElecomTutorialKeys.loginPassword,
                                          controller: _passwordController,
                                          hintText: 'Enter your password',
                                          icon: Icons.lock_outline_rounded,
                                          height: fieldH,
                                          fontSize: fs,
                                          obscureText: vm.obscurePassword,
                                          validator: (v) {
                                            if (v == null || v.isEmpty) {
                                              return 'Please enter your password';
                                            }
                                            return null;
                                          },
                                          suffix: IconButton(
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () => vm.togglePasswordVisibility(),
                                            icon: AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 180),
                                              child: Icon(
                                                vm.obscurePassword
                                                    ? Icons.visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                key: ValueKey(vm.obscurePassword),
                                                color: _kTextMuted,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: compact ? 14.0 : 16.0),

                                      // Terms row
                                      FadeInUp(
                                        duration: const Duration(milliseconds: 540),
                                        delay: const Duration(milliseconds: 200),
                                        from: 8,
                                        child: _WebTermsRow(
                                          compact: compact,
                                          accepted: vm.acceptedTerms,
                                          onToggle: () => context.read<LoginViewModel>().toggleAcceptedTerms(),
                                          onViewTerms: () async {
                                            final accepted = await showModalBottomSheet<bool>(
                                              context: context,
                                              isScrollControlled: true,
                                              isDismissible: false,
                                              enableDrag: false,
                                              backgroundColor: Colors.transparent,
                                              builder: (ctx) => FractionallySizedBox(
                                                heightFactor: 0.94,
                                                child: ClipRRect(
                                                  borderRadius: const BorderRadius.vertical(
                                                    top: Radius.circular(20),
                                                  ),
                                                  child: const ElecomTermsConditionsScreen(
                                                    requireAgreement: true,
                                                  ),
                                                ),
                                              ),
                                            );
                                            if (!context.mounted) return;
                                            context.read<LoginViewModel>().setAcceptedTerms(accepted == true);
                                          },
                                        ),
                                      ),
                                      SizedBox(height: compact ? 14.0 : 16.0),

                                      // Sign In button
                                      FadeInUp(
                                        duration: const Duration(milliseconds: 560),
                                        delay: const Duration(milliseconds: 280),
                                        from: 10,
                                        child: _WebSignInButton(
                                          key: ElecomTutorialKeys.loginSubmit,
                                          height: btnH,
                                          isLoading: vm.isLoading,
                                          isPressed: _buttonPressed,
                                          shimmerController: _shimmerController,
                                          onTapDown: () => setState(() => _buttonPressed = true),
                                          onTapCancel: () => setState(() => _buttonPressed = false),
                                          onTapUp: () => setState(() => _buttonPressed = false),
                                          onPressed: vm.isLoading ? null : (vm.acceptedTerms ? _submit : null),
                                        ),
                                      ),

                                      // Divider below Sign In
                                      SizedBox(height: compact ? 10.0 : 12.0),
                                      Divider(
                                        color: _kBorder.withValues(alpha: 0.7),
                                        thickness: 1,
                                        height: 1,
                                      ),
                                      SizedBox(height: compact ? 2.0 : 4.0),

                                      // Forgot password
                                      FadeInUp(
                                        duration: const Duration(milliseconds: 520),
                                        delay: const Duration(milliseconds: 340),
                                        from: 6,
                                        child: TextButton(
                                          key: ElecomTutorialKeys.loginForgot,
                                          style: TextButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            minimumSize: const Size(0, 36),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => const ForgotPasswordScreen(),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            'Forgot Password?',
                                            style: GoogleFonts.poppins(
                                              color: _kNavyLight,
                                              fontWeight: FontWeight.w700,
                                              fontSize: compact ? 11.5 : 12.5,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Footer: always at bottom, keyboard pushes it away ──
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '© 2026 USTP Oroquieta Electoral Commission',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: _kTextMuted.withValues(alpha: 0.7),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Background ───────────────────────────────────────────────────────────────

class _WebBackdrop extends StatelessWidget {
  const _WebBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Light gradient base matching web left panel feel
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFF4F8FF),
                Color(0xFFEAF0FB),
                Color(0xFFDDE7F5),
              ],
              stops: [0, 0.35, 0.70, 1],
            ),
          ),
        ),
        // Subtle navy top accent strip (like web header area)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kNavy, _kNavyLight, _kGold],
              ),
            ),
          ),
        ),
        // Soft gold glow bottom-right — removed
        // Soft navy glow top-left — removed
      ],
    );
  }
}

// ─── Form Card ────────────────────────────────────────────────────────────────

class _WebFormCard extends StatelessWidget {
  const _WebFormCard({required this.compact, required this.child});

  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4.0 : 8.0,
          ),
          child: child,
        )
        .animate()
        .fadeIn(duration: 600.ms, delay: 120.ms)
        .slideY(begin: 0.04, end: 0, duration: 600.ms, curve: Curves.easeOutCubic);
  }
}

// ─── Input Field ──────────────────────────────────────────────────────────────

class _WebInputField extends StatefulWidget {
  const _WebInputField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.validator,
    required this.height,
    required this.fontSize,
    this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String hintText;
  final String? Function(String?) validator;
  final double height;
  final double fontSize;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  State<_WebInputField> createState() => _WebInputFieldState();
}

class _WebInputFieldState extends State<_WebInputField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      focusNode: _focusNode,
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText,
      validator: widget.validator,
      cursorColor: _kGold,
      style: GoogleFonts.poppins(
        color: _kTextDark,
        fontWeight: FontWeight.w500,
        fontSize: widget.fontSize,
      ),
      decoration: InputDecoration(
        prefixIcon: widget.icon == null
            ? null
            : Icon(
                widget.icon,
                color: _kGold,
                size: 18,
              ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 40),
        hintText: widget.hintText,
        filled: false,
        hintStyle: GoogleFonts.poppins(
          color: _kTextMuted.withValues(alpha: 0.65),
          fontWeight: FontWeight.w400,
          fontSize: widget.fontSize,
        ),
        contentPadding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
        suffixIcon: widget.suffix,
        // Underline-only style matching the web
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: _kBorder,
            width: 1.2,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: _kGold,
            width: 1.8,
          ),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: Color(0xFFDC2626),
            width: 1.2,
          ),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: Color(0xFFDC2626),
            width: 1.8,
          ),
        ),
        errorStyle: GoogleFonts.poppins(
          color: const Color(0xFFDC2626),
          fontWeight: FontWeight.w600,
          fontSize: 10,
          height: 1.2,
        ),
      ),
    );
  }
}

// ─── Sign In Button ───────────────────────────────────────────────────────────

class _WebSignInButton extends StatelessWidget {
  const _WebSignInButton({
    super.key,
    required this.height,
    required this.isLoading,
    required this.isPressed,
    required this.shimmerController,
    required this.onTapDown,
    required this.onTapCancel,
    required this.onTapUp,
    required this.onPressed,
  });

  final double height;
  final bool isLoading;
  final bool isPressed;
  final AnimationController shimmerController;
  final VoidCallback onTapDown;
  final VoidCallback onTapCancel;
  final VoidCallback onTapUp;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null && !isLoading;

    return AnimatedBuilder(
      animation: shimmerController,
      builder: (context, _) {
        final shimmerX = -1.2 + shimmerController.value * 2.4;
        return AnimatedScale(
          scale: isPressed ? 0.975 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: disabled ? 0.35 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTapDown: disabled ? null : (_) => onTapDown(),
              onTapCancel: disabled ? null : onTapCancel,
              onTapUp: disabled ? null : (_) => onTapUp(),
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: disabled
                        ? [_kBorder, _kBorder, _kBorder]
                        : [const Color(0xFFE8920A), _kGold, _kGoldLight, _kGold, const Color(0xFFE8920A)],
                    stops: disabled ? const [0, 0.5, 1] : const [0, 0.25, 0.5, 0.75, 1],
                  ),
                  boxShadow: disabled
                      ? null
                      : [
                          BoxShadow(
                            color: _kGold.withValues(alpha: 0.55),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                child: Stack(
                  children: [
                    // Shimmer sweep (only when enabled)
                    if (!disabled)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Transform.translate(
                            offset: Offset(shimmerX * 280, 0),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _kWhite.withValues(alpha: 0),
                                    _kWhite.withValues(alpha: 0.3),
                                    _kWhite.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Button content
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: onPressed,
                        child: SizedBox(
                          height: height,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!isLoading) ...[
                                Icon(
                                  Icons.shield_outlined,
                                  color: disabled ? _kTextMuted : _kNavy,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                              ],
                              isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor: AlwaysStoppedAnimation<Color>(_kNavy),
                                      ),
                                    )
                                  : Text(
                                      'Sign In',
                                      style: GoogleFonts.poppins(
                                        color: disabled ? _kTextMuted : _kNavy,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15.5,
                                      ),
                                    ),
                            ],
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
      },
    );
  }
}

// ─── Terms Row ────────────────────────────────────────────────────────────────

class _WebTermsRow extends StatelessWidget {
  const _WebTermsRow({
    required this.compact,
    required this.accepted,
    required this.onToggle,
    required this.onViewTerms,
  });

  final bool compact;
  final bool accepted;
  final VoidCallback onToggle;
  final VoidCallback onViewTerms;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double fs = 12.0;
        const double boxSize = 17.0;
        const double iconSize = 11.5;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Checkbox — tap only toggles accepted state
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: boxSize,
                height: boxSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: accepted ? _kNavy : _kWhite,
                  border: Border.all(
                    color: accepted ? _kNavy : _kBorder,
                    width: 1.5,
                  ),
                  boxShadow: accepted
                      ? [
                          BoxShadow(
                            color: _kNavy.withValues(alpha: 0.2),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  child: accepted
                      ? const Icon(
                          Icons.check_rounded,
                          key: ValueKey('checked'),
                          size: iconSize,
                          color: _kWhite,
                        )
                      : const SizedBox(key: ValueKey('unchecked')),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Text — "Accept the " is plain, "Terms and Conditions" navigates
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(
                    color: _kTextMuted,
                    fontWeight: FontWeight.w400,
                    fontSize: fs,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'Accept the '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: onViewTerms,
                        child: Text(
                          'Terms and Conditions',
                          style: GoogleFonts.poppins(
                            color: _kNavy,
                            fontWeight: FontWeight.w700,
                            fontSize: fs,
                            height: 1.4,
                            decoration: TextDecoration.underline,
                            decorationColor: _kNavy,
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
      },
    );
  }
}
