import 'dart:math' as math;

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
  late final AnimationController _logoFloatController;
  late final AnimationController _buttonPulseController;
  bool _buttonPressed = false;
  bool _loginTutorialScheduled = false;

  final ElecomMobileApi _mobileApi = ElecomMobileApi();

  Future<void> _openTermsForDecision() async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.94,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: const ElecomTermsConditionsScreen(requireAgreement: true),
          ),
        );
      },
    );
    if (!mounted) return;
    context.read<LoginViewModel>().setAcceptedTerms(accepted == true);
  }

  Future<void> _submit() async {
    final vm = context.read<LoginViewModel>();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

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

      // Clear any lingering toasts (e.g. previous login error) before navigating.
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
    _logoFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);
    _buttonPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
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
    _logoFloatController.dispose();
    _buttonPulseController.dispose();
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();
    final lightLoginTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.black,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      checkboxTheme: const CheckboxThemeData(
        checkColor: WidgetStatePropertyAll<Color>(Colors.white),
      ),
    );

    return Theme(
      data: lightLoginTheme,
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(platformBrightness: Brightness.light),
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFF),
          body: Stack(
            fit: StackFit.expand,
            children: [
              const _LoginBackdrop(),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    final compact = height < 680;
                    final horizontalPadding = (width * 0.07).clamp(18.0, 28.0);
                    final topPadding = compact ? 10.0 : height * 0.02;
                    final bottomPadding = compact ? 24.0 : 30.0;
                    final logoSize = (width * 0.20).clamp(62.0, 86.0);
                    final titleSize = (width * 0.068).clamp(22.0, 26.0);
                    final subtitleSize = compact ? 11.0 : 12.0;
                    final fieldHeight = compact ? 52.0 : 56.0;
                    final buttonHeight = compact ? 54.0 : 56.0;
                    final heroGap = compact ? height * 0.02 : height * 0.03;
                    final titleGap = compact ? 5.0 : 8.0;
                    final formGap = compact ? height * 0.028 : height * 0.04;
                    final inputGap = compact ? 14.0 : 18.0;
                    final buttonTopGap = compact ? 20.0 : height * 0.028;
                    final termsGap = compact ? 14.0 : height * 0.024;

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        topPadding,
                        horizontalPadding,
                        bottomPadding,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(0, height - topPadding - bottomPadding),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 430),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _LoginBrandHero(
                                    controller: _logoFloatController,
                                    logoSize: logoSize,
                                    subtitleSize: subtitleSize,
                                    compact: compact,
                                  ),
                                  SizedBox(height: heroGap),
                                  FadeInUp(
                                    duration: const Duration(milliseconds: 650),
                                    from: compact ? 9 : 16,
                                    child: _GradientElecomTitle(
                                        fontSize: titleSize,
                                      ),
                                    ),
                                  SizedBox(height: titleGap + 2),
                                  FadeInUp(
                                    duration: const Duration(milliseconds: 720),
                                    delay: const Duration(milliseconds: 120),
                                    from: compact ? 8 : 12,
                                    child: Text(
                                      'Use your student account to continue',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF1F2937)
                                            .withValues(alpha: 0.62),
                                        fontWeight: FontWeight.w500,
                                        fontSize: subtitleSize,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: formGap),
                                  SlideInUp(
                                    duration: const Duration(milliseconds: 690),
                                    delay: const Duration(milliseconds: 180),
                                    from: compact ? 12 : 22,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        _RoundedField(
                                          key: ElecomTutorialKeys.loginStudentId,
                                          controller: _studentIdController,
                                          hintText: 'Enter your student ID',
                                          icon: Icons.person_outline_rounded,
                                          keyboardType: TextInputType.text,
                                          height: fieldHeight,
                                          fontSize: compact ? 13.0 : 14.0,
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) {
                                              return 'Please enter your student id';
                                            }
                                            return null;
                                          },
                                        ),
                                        SizedBox(height: inputGap),
                                        _RoundedField(
                                          key: ElecomTutorialKeys.loginPassword,
                                          controller: _passwordController,
                                          hintText: 'Enter your password',
                                          icon: Icons.lock_outline_rounded,
                                          obscureText: vm.obscurePassword,
                                          height: fieldHeight,
                                          fontSize: compact ? 13.0 : 14.0,
                                          validator: (v) {
                                            if (v == null || v.isEmpty) {
                                              return 'Please enter your password';
                                            }
                                            return null;
                                          },
                                          suffix: IconButton(
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () =>
                                                vm.togglePasswordVisibility(),
                                            icon: Icon(
                                              vm.obscurePassword
                                                  ? Icons.visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              color: const Color(0xFF475569)
                                                  .withValues(alpha: 0.72),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: buttonTopGap),
                                  FadeInUp(
                                    duration: const Duration(milliseconds: 680),
                                    delay: const Duration(milliseconds: 320),
                                    from: compact ? 8 : 14,
                                    child: AnimatedBuilder(
                                      animation: _buttonPulseController,
                                      builder: (context, child) {
                                        final pulse = 0.24 +
                                            (_buttonPulseController.value * 0.18);
                                        return AnimatedScale(
                                          scale: _buttonPressed ? 0.975 : 1,
                                          duration: const Duration(
                                            milliseconds: 120,
                                          ),
                                          curve: Curves.easeOut,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(28),
                                              color: const Color(0xFF0B5CFF),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF0B5CFF)
                                                      .withValues(alpha: pulse),
                                                  blurRadius: 18,
                                                  spreadRadius: 0,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                            ),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: GestureDetector(
                                        key: ElecomTutorialKeys.loginSubmit,
                                        onTapDown: (_) =>
                                            setState(() => _buttonPressed = true),
                                        onTapCancel: () => setState(
                                          () => _buttonPressed = false,
                                        ),
                                        onTapUp: (_) => setState(
                                          () => _buttonPressed = false,
                                        ),
                                        child: ElevatedButton(
                                          onPressed: vm.isLoading ? null : _submit,
                                          style: ElevatedButton.styleFrom(
                                            minimumSize:
                                                Size.fromHeight(buttonHeight),
                                            backgroundColor: Colors.transparent,
                                            disabledBackgroundColor:
                                                Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(28),
                                            ),
                                            elevation: 0,
                                          ),
                                          child: vm.isLoading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(
                                                      Colors.white,
                                                    ),
                                                  ),
                                                )
                                              : Text(
                                                  'Login',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: termsGap),
                                  FadeInUp(
                                    duration: const Duration(milliseconds: 620),
                                    delay: const Duration(milliseconds: 430),
                                    from: compact ? 8 : 12,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Checkbox(
                                          value: vm.acceptedTerms,
                                          onChanged: (_) =>
                                              _openTermsForDecision(),
                                          activeColor: const Color(0xFFFFC107),
                                          checkColor: Colors.black,
                                          visualDensity: VisualDensity.compact,
                                          side: BorderSide(
                                            color: const Color(0xFF475569)
                                                .withValues(alpha: 0.72),
                                            width: 1.4,
                                          ),
                                        ),
                                        Flexible(
                                          child: Wrap(
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                'I accept the ',
                                                style: GoogleFonts.poppins(
                                                  color: const Color(0xFF111827)
                                                      .withValues(alpha: 0.78),
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: compact ? 11.5 : 12.5,
                                                ),
                                              ),
                                              InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                onTap: _openTermsForDecision,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    vertical: 3,
                                                  ),
                                                  child: Text(
                                                    'Terms & Conditions',
                                                    style: GoogleFonts.poppins(
                                                      color:
                                                          const Color(0xFFE0A800),
                                                      fontWeight: FontWeight.w800,
                                                      fontSize:
                                                          compact ? 11.5 : 12.5,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: compact ? 4 : 7),
                                  FadeInUp(
                                    duration: const Duration(milliseconds: 600),
                                    delay: const Duration(milliseconds: 500),
                                    from: 8,
                                    child: TextButton(
                                      key: ElecomTutorialKeys.loginForgot,
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        minimumSize: const Size(0, 36),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ForgotPasswordScreen(),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'FORGOT PASSWORD?',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF0B5CFF),
                                          fontWeight: FontWeight.w800,
                                          fontSize: compact ? 11.5 : 12.5,
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
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundedField extends StatelessWidget {
  const _RoundedField({
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
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: GoogleFonts.poppins(
        color: const Color(0xFF0F172A),
        fontWeight: FontWeight.w800,
        fontSize: fontSize,
      ),
      decoration: InputDecoration(
        prefixIcon: icon == null
            ? null
            : Icon(
                icon,
                color: const Color(0xFFFFC107).withValues(alpha: 0.90),
                size: 20,
              ),
        constraints: BoxConstraints(minHeight: height),
        hintText: hintText,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.72),
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFF64748B).withValues(alpha: 0.78),
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: (height - 24).clamp(12.0, 16.0) / 2,
        ),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: const Color(0xFFCBD5E1).withValues(alpha: 0.88),
            width: 1.4,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: const Color(0xFFCBD5E1).withValues(alpha: 0.88),
            width: 1.4,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF0B5CFF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.2),
        ),
        errorStyle: const TextStyle(
          color: Color(0xFFFFB4B4),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GradientElecomTitle extends StatelessWidget {
  const _GradientElecomTitle({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final baseStyle = GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.08,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Sign In to ',
            style: baseStyle.copyWith(color: const Color(0xFF0F172A)),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                return const LinearGradient(
                  colors: [
                    Color(0xFF0B5CFF),
                    Color(0xFFFFD54A),
                  ],
                ).createShader(bounds);
              },
              child: Text(
                'ELECOM',
                style: baseStyle.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF8FAFF),
            Color(0xFFF3F7FF),
            Color(0xFFFFFCF0),
          ],
          stops: [0, 0.42, 0.72, 1],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    Color(0xFFEAF3FF),
                    Color(0x00FFFFFF),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -150,
            left: -80,
            right: -80,
            child: _SoftGlow(
              size: 360,
              color: const Color(0xFF0B5CFF).withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            top: 34,
            right: -105,
            child: _SoftGlow(
              size: 190,
              color: const Color(0xFFFFC107).withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -120,
            child: _SoftGlow(
              size: 220,
              color: const Color(0xFF0B5CFF).withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftGlow extends StatelessWidget {
  const _SoftGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0),
          ],
        ),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          begin: const Offset(0.94, 0.94),
          end: const Offset(1.06, 1.06),
          duration: 3200.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _LoginBrandHero extends StatelessWidget {
  const _LoginBrandHero({
    required this.controller,
    required this.logoSize,
    required this.subtitleSize,
    required this.compact,
  });

  final AnimationController controller;
  final double logoSize;
  final double subtitleSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FadeInDown(
      duration: const Duration(milliseconds: 760),
      from: 16,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final dy = math.sin(controller.value * math.pi) * -8;
              return Transform.translate(
                offset: Offset(0, dy),
                child: child,
              );
            },
            child: _LayeredLogoMark(size: logoSize),
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            'Secure campus election access',
            style: GoogleFonts.poppins(
              color: const Color(0xFF334155).withValues(alpha: 0.62),
              fontWeight: FontWeight.w400,
              fontSize: subtitleSize,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayeredLogoMark extends StatelessWidget {
  const _LayeredLogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.28,
      height: size * 1.28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 0.78,
            child: Container(
              width: size * 1.02,
              height: size * 1.02,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.24),
                color: Colors.white.withValues(alpha: 0.72),
                border: Border.all(
                  color: const Color(0xFF0B5CFF).withValues(alpha: 0.10),
                ),
              ),
            ),
          ),
          Container(
            width: size * 1.00,
            height: size * 1.00,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF0B5CFF).withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B5CFF).withValues(alpha: 0.10),
                  blurRadius: size * 0.20,
                  spreadRadius: size * 0.015,
                ),
              ],
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .rotate(
                duration: 9000.ms,
                begin: 0,
                end: 1,
                curve: Curves.linear,
              ),
          Container(
            width: size * 0.70,
            height: size * 0.70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFE2E8F0),
              ),
            ),
            padding: EdgeInsets.all(size * 0.075),
            child: Opacity(
              opacity: 0.96,
              child: Image.asset(
                'assets/elecom.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
