import 'dart:math' as math;
import 'dart:ui' as ui;

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
  late final AnimationController _ambientController;
  late final AnimationController _buttonPulseController;
  late final AnimationController _shimmerController;
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
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7200),
    )..repeat(reverse: true);
    _buttonPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
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
    _ambientController.dispose();
    _buttonPulseController.dispose();
    _shimmerController.dispose();
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();
    final loginTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF050607),
      checkboxTheme: const CheckboxThemeData(
        checkColor: WidgetStatePropertyAll<Color>(Colors.white),
      ),
    );

    return Theme(
      data: loginTheme,
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(platformBrightness: Brightness.dark),
        child: Scaffold(
          backgroundColor: const Color(0xFF050607),
          body: Stack(
            fit: StackFit.expand,
            children: [
              _LoginBackdrop(controller: _ambientController),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    final compact = height < 700;
                    final horizontalPadding = (width * 0.07).clamp(20.0, 30.0);
                    final topPadding = compact ? 10.0 : height * 0.032;
                    final bottomPadding = compact ? 18.0 : 28.0;
                    final logoSize = (width * 0.17).clamp(52.0, 68.0);
                    final wordmarkWidth = (width * 0.48).clamp(164.0, 212.0);
                    final titleSize = (width * 0.072).clamp(24.0, 30.0);
                    final subtitleSize = compact ? 11.0 : 12.0;
                    final fieldHeight = compact ? 46.0 : 50.0;
                    final buttonHeight = compact ? 48.0 : 52.0;
                    final heroGap = compact ? 10.0 : 15.0;
                    final titleGap = compact ? 5.0 : 7.0;
                    final formGap = compact ? 19.0 : 26.0;
                    final inputGap = compact ? 11.0 : 13.0;
                    final buttonTopGap = compact ? 16.0 : 19.0;
                    final termsGap = compact ? 11.0 : 13.0;

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
                          minHeight: math.max(
                            0,
                            height - topPadding - bottomPadding,
                          ),
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
                                    logoSize: logoSize,
                                    wordmarkWidth: wordmarkWidth,
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
                                        color: const Color(
                                          0xFF111827,
                                        ).withValues(alpha: 0.64),
                                        fontWeight: FontWeight.w500,
                                        fontSize: subtitleSize,
                                      ),
                                    ),
                                  ),
                                  _LoginFormPanel(
                                    topMargin: formGap,
                                    sideOverflow: 0,
                                    compact: compact,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        SlideInUp(
                                          duration: const Duration(
                                            milliseconds: 690,
                                          ),
                                          delay: const Duration(
                                            milliseconds: 180,
                                          ),
                                          from: compact ? 12 : 22,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              _RoundedField(
                                                key: ElecomTutorialKeys
                                                    .loginStudentId,
                                                controller:
                                                    _studentIdController,
                                                hintText:
                                                    'Enter your student ID',
                                                icon: Icons
                                                    .person_outline_rounded,
                                                keyboardType:
                                                    TextInputType.text,
                                                height: fieldHeight,
                                                fontSize: compact ? 13.0 : 14.0,
                                                validator: (v) {
                                                  if (v == null ||
                                                      v.trim().isEmpty) {
                                                    return 'Please enter your student id';
                                                  }
                                                  return null;
                                                },
                                              ),
                                              SizedBox(height: inputGap),
                                              _RoundedField(
                                                key: ElecomTutorialKeys
                                                    .loginPassword,
                                                controller: _passwordController,
                                                hintText: 'Enter your password',
                                                icon:
                                                    Icons.lock_outline_rounded,
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
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  onPressed: () => vm
                                                      .togglePasswordVisibility(),
                                                  icon: AnimatedSwitcher(
                                                    duration: const Duration(
                                                      milliseconds: 180,
                                                    ),
                                                    child: Icon(
                                                      vm.obscurePassword
                                                          ? Icons
                                                                .visibility_off_outlined
                                                          : Icons
                                                                .visibility_outlined,
                                                      key: ValueKey(
                                                        vm.obscurePassword,
                                                      ),
                                                      color: const Color(
                                                        0xFFCBD5E1,
                                                      ).withValues(alpha: 0.66),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: buttonTopGap),
                                        FadeInUp(
                                          duration: const Duration(
                                            milliseconds: 680,
                                          ),
                                          delay: const Duration(
                                            milliseconds: 320,
                                          ),
                                          from: compact ? 8 : 14,
                                          child: _PremiumLoginButton(
                                            key: ElecomTutorialKeys.loginSubmit,
                                            height: buttonHeight,
                                            isLoading: vm.isLoading,
                                            isPressed: _buttonPressed,
                                            pulseController:
                                                _buttonPulseController,
                                            shimmerController:
                                                _shimmerController,
                                            onTapDown: () => setState(
                                              () => _buttonPressed = true,
                                            ),
                                            onTapCancel: () => setState(
                                              () => _buttonPressed = false,
                                            ),
                                            onTapUp: () => setState(
                                              () => _buttonPressed = false,
                                            ),
                                            onPressed: vm.isLoading
                                                ? null
                                                : _submit,
                                          ),
                                        ),
                                        SizedBox(height: termsGap),
                                        FadeInUp(
                                          duration: const Duration(
                                            milliseconds: 620,
                                          ),
                                          delay: const Duration(
                                            milliseconds: 430,
                                          ),
                                          from: compact ? 8 : 12,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              _PremiumCheckbox(
                                                value: vm.acceptedTerms,
                                                onTap: _openTermsForDecision,
                                              ),
                                              const SizedBox(width: 11),
                                              Flexible(
                                                child: Wrap(
                                                  crossAxisAlignment:
                                                      WrapCrossAlignment.center,
                                                  children: [
                                                    Text(
                                                      'I accept the ',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            color:
                                                                const Color(
                                                                  0xFFFFFFFF,
                                                                ).withValues(
                                                                  alpha: 0.72,
                                                                ),
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            fontSize: compact
                                                                ? 12.0
                                                                : 13.0,
                                                          ),
                                                    ),
                                                    InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      onTap:
                                                          _openTermsForDecision,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 3,
                                                            ),
                                                        child: Text(
                                                          'Terms & Conditions',
                                                          style:
                                                              GoogleFonts.poppins(
                                                                color:
                                                                    const Color(
                                                                      0xFFFACC15,
                                                                    ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                fontSize:
                                                                    compact
                                                                    ? 12.0
                                                                    : 13.0,
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
                                        SizedBox(height: compact ? 2 : 5),
                                        FadeInUp(
                                          duration: const Duration(
                                            milliseconds: 600,
                                          ),
                                          delay: const Duration(
                                            milliseconds: 500,
                                          ),
                                          from: 8,
                                          child: TextButton(
                                            key: ElecomTutorialKeys.loginForgot,
                                            style: TextButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              minimumSize: const Size(0, 36),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
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
                                                color: const Color(
                                                  0xFF60A5FA,
                                                ).withValues(alpha: 0.92),
                                                fontWeight: FontWeight.w700,
                                                fontSize: compact ? 11.4 : 12.2,
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

class _LoginFormPanel extends StatelessWidget {
  const _LoginFormPanel({
    required this.topMargin,
    required this.sideOverflow,
    required this.compact,
    required this.child,
  });

  final double topMargin;
  final double sideOverflow;
  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topMargin),
      child:
          ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 17 : 20,
                      compact ? 18 : 21,
                      compact ? 17 : 20,
                      compact ? 14 : 17,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: const Color(0xFF0F172A).withValues(alpha: 0.69),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                        width: 1,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.16),
                          const Color(0xFF0F172A).withValues(alpha: 0.68),
                          Colors.black.withValues(alpha: 0.78),
                        ],
                        stops: const [0, 0.42, 1],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.42),
                          blurRadius: 34,
                          offset: const Offset(0, 20),
                        ),
                        BoxShadow(
                          color: const Color(
                            0xFF2563EB,
                          ).withValues(alpha: 0.18),
                          blurRadius: 40,
                          offset: const Offset(-14, -12),
                        ),
                        BoxShadow(
                          color: const Color(
                            0xFFFACC15,
                          ).withValues(alpha: 0.08),
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
                              painter: _PanelBoundaryPatternPainter(),
                            ),
                          ),
                        ),
                        child,
                        Positioned(
                          top: 0,
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.42),
                                  const Color(
                                    0xFFFACC15,
                                  ).withValues(alpha: 0.32),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 620.ms, delay: 170.ms)
              .slideY(
                begin: 0.045,
                end: 0,
                duration: 620.ms,
                curve: Curves.easeOutCubic,
              ),
    );
  }
}

class _PanelBoundaryPatternPainter extends CustomPainter {
  const _PanelBoundaryPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height * 0.36;
    final darkPaint = Paint()
      ..color = const Color(0xFF111827).withValues(alpha: 0.22);
    final lightPaint = Paint()..color = Colors.white.withValues(alpha: 0.20);
    final goldPaint = Paint()
      ..color = const Color(0xFFFACC15).withValues(alpha: 0.15);

    for (var x = 8.0; x <= size.width; x += 14) {
      for (var y = 4.0; y <= size.height - 4; y += 14) {
        final distance = (y - centerY).abs();
        final fade = (1 - (distance / 46)).clamp(0.0, 1.0);
        if (fade <= 0) continue;

        final paint = y < centerY ? darkPaint : lightPaint;
        paint.color = paint.color.withValues(
          alpha: (y < centerY ? 0.18 : 0.16) * fade,
        );
        canvas.drawCircle(Offset(x, y), y < centerY ? 0.9 : 1.0, paint);
      }
    }

    for (var x = 24.0; x <= size.width; x += 42) {
      final y = centerY + ((x ~/ 36).isEven ? -6 : 10);
      canvas.drawCircle(Offset(x, y), 1.25, goldPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PremiumCheckbox extends StatelessWidget {
  const _PremiumCheckbox({required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: AnimatedScale(
            scale: value ? 1.04 : 1,
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: value
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF020617),
                          Color(0xFF111827),
                          Color(0xFFFACC15),
                        ],
                        stops: [0, 0.56, 1],
                      )
                    : null,
                color: value ? null : Colors.white.withValues(alpha: 0.045),
                border: Border.all(
                  color: value
                      ? const Color(0xFFFACC15).withValues(alpha: 0.54)
                      : Colors.white.withValues(alpha: 0.34),
                  width: 1.2,
                ),
                boxShadow: value
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFFFACC15,
                          ).withValues(alpha: 0.24),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: value
                    ? const Icon(
                        Icons.check_rounded,
                        key: ValueKey('checked'),
                        size: 14,
                        color: Colors.white,
                      )
                    : const SizedBox(key: ValueKey('unchecked')),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumLoginButton extends StatelessWidget {
  const _PremiumLoginButton({
    super.key,
    required this.height,
    required this.isLoading,
    required this.isPressed,
    required this.pulseController,
    required this.shimmerController,
    required this.onTapDown,
    required this.onTapCancel,
    required this.onTapUp,
    required this.onPressed,
  });

  final double height;
  final bool isLoading;
  final bool isPressed;
  final AnimationController pulseController;
  final AnimationController shimmerController;
  final VoidCallback onTapDown;
  final VoidCallback onTapCancel;
  final VoidCallback onTapUp;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulseController, shimmerController]),
      builder: (context, _) {
        final pulse = 0.22 + (pulseController.value * 0.18);
        final shimmerX = -1.15 + (shimmerController.value * 2.3);

        return AnimatedScale(
          scale: isPressed ? 0.972 : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            onTapDown: (_) => onTapDown(),
            onTapCancel: onTapCancel,
            onTapUp: (_) => onTapUp(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28 + pulse),
                    blurRadius: 22,
                    offset: const Offset(-8, 10),
                  ),
                  BoxShadow(
                    color: const Color(0xFFFACC15).withValues(alpha: pulse),
                    blurRadius: 26,
                    offset: const Offset(18, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF020617),
                              Color(0xFF111827),
                              Color(0xFFFACC15),
                            ],
                            stops: [0, 0.58, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(shimmerX * 260, 0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.28),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: onPressed,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size.fromHeight(height),
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Login',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
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

class _RoundedField extends StatefulWidget {
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
  State<_RoundedField> createState() => _RoundedFieldState();
}

class _RoundedFieldState extends State<_RoundedField> {
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
    final focused = _focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: focused ? 0.075 : 0.052),
        border: Border.all(
          color: focused
              ? const Color(0xFFFACC15).withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: 0.13),
          width: focused ? 1.35 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: focused
                ? const Color(0xFFFACC15).withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: 0.18),
            blurRadius: focused ? 18 : 10,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.035),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 18,
            right: 18,
            top: 0,
            child: AnimatedOpacity(
              opacity: focused ? 0.46 : 0.18,
              duration: const Duration(milliseconds: 220),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.55),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          TextFormField(
            focusNode: _focusNode,
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            validator: widget.validator,
            cursorColor: const Color(0xFFFACC15),
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.94),
              fontWeight: FontWeight.w600,
              fontSize: widget.fontSize,
            ),
            decoration: InputDecoration(
              prefixIcon: widget.icon == null
                  ? null
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        widget.icon,
                        key: ValueKey(focused),
                        color: focused
                            ? const Color(0xFFFACC15)
                            : const Color(0xFF60A5FA),
                        size: focused ? 19 : 18,
                      ),
                    ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 46,
                minHeight: 42,
              ),
              constraints: BoxConstraints(minHeight: widget.height),
              hintText: widget.hintText,
              filled: false,
              hintStyle: GoogleFonts.poppins(
                color: const Color(0xFF94A3B8).withValues(alpha: 0.72),
                fontWeight: FontWeight.w500,
                fontSize: widget.fontSize - 1,
              ),
              contentPadding: const EdgeInsets.fromLTRB(0, 12, 14, 11),
              suffixIcon: widget.suffix,
              border: InputBorder.none,
              errorStyle: GoogleFonts.poppins(
                color: const Color(0xFFFACC15),
                fontWeight: FontWeight.w700,
                fontSize: 10,
                height: 0.7,
              ),
            ),
          ),
        ],
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
            style: baseStyle.copyWith(color: const Color(0xFF111827)),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                return const LinearGradient(
                  colors: [Color(0xFFFACC15), Color(0xFFD4A017)],
                ).createShader(bounds);
              },
              child: Text(
                'VOTE',
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
  const _LoginBackdrop({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final drift = math.sin(controller.value * math.pi * 2);
        final counterDrift = math.cos(controller.value * math.pi * 2);

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
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.8, -0.72),
                  radius: 1.18,
                  colors: [Color(0x22FFFFFF), Color(0x00000000)],
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(18 * drift, 10 * counterDrift),
              child: const _BlurredGlow(
                alignment: Alignment(0.82, -0.86),
                size: 250,
                color: Color(0xFF2563EB),
                alpha: 0.22,
              ),
            ),
            Transform.translate(
              offset: Offset(-16 * counterDrift, 8 * drift),
              child: const _BlurredGlow(
                alignment: Alignment(-0.92, -0.42),
                size: 210,
                color: Color(0xFFFACC15),
                alpha: 0.18,
              ),
            ),
            Transform.translate(
              offset: Offset(12 * counterDrift, -12 * drift),
              child: const _BlurredGlow(
                alignment: Alignment(0.42, 0.74),
                size: 320,
                color: Color(0xFF2563EB),
                alpha: 0.13,
              ),
            ),
            const Positioned.fill(child: _MeshLighting()),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _AtmosphericTexturePainter(controller.value),
                ),
              ),
            ),
            const Positioned.fill(child: _BoundaryPattern()),
            const Positioned(
              top: 28,
              left: 14,
              child: _DotPattern(color: Color(0xFF111827), alpha: 0.25),
            ),
            const Positioned(
              top: 138,
              right: 14,
              child: _DotPattern(color: Color(0xFFFACC15), alpha: 0.20),
            ),
            const Positioned(
              left: 18,
              bottom: 86,
              child: _DotPattern(color: Colors.white, alpha: 0.18),
            ),
            const Positioned(
              right: 10,
              bottom: 42,
              child: _DotPattern(color: Color(0xFFFACC15), alpha: 0.15),
            ),
            Positioned(
              top: 54,
              left: 0,
              right: 0,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 2.6, sigmaY: 2.6),
                child: Opacity(
                  opacity: 0.024,
                  child: Image.asset(
                    'assets/img_text/elecom_black.png',
                    height: 158,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const Positioned(
              top: -48,
              right: -46,
              child: _CircleOutline(size: 132),
            ),
            const Positioned(
              left: -56,
              bottom: 48,
              child: _CircleOutline(size: 118),
            ),
          ],
        );
      },
    );
  }
}

class _BlurredGlow extends StatelessWidget {
  const _BlurredGlow({
    required this.alignment,
    required this.size,
    required this.color,
    required this.alpha,
  });

  final Alignment alignment;
  final double size;
  final Color color;
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

class _MeshLighting extends StatelessWidget {
  const _MeshLighting();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.35, -0.12),
          radius: 1.06,
          colors: [Color(0x14FACC15), Color(0x0E2563EB), Color(0x00000000)],
          stops: [0, 0.45, 1],
        ),
      ),
    );
  }
}

class _AtmosphericTexturePainter extends CustomPainter {
  const _AtmosphericTexturePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    _paintStreaks(canvas, size);
    _paintParticles(canvas, size);
    _paintGrain(canvas, size);
  }

  void _paintStreaks(Canvas canvas, Size size) {
    final blue = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.18, size.height * 0.14),
        Offset(size.width * 0.88, size.height * 0.35),
        [
          Colors.white.withValues(alpha: 0),
          const Color(0xFF2563EB).withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0),
        ],
        [0, 0.5, 1],
      )
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final gold = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * -0.10, size.height * 0.36),
        Offset(size.width * 0.70, size.height * 0.18),
        [
          Colors.white.withValues(alpha: 0),
          const Color(0xFFFACC15).withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0),
        ],
        [0, 0.5, 1],
      )
      ..strokeWidth = 1.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final drift = math.sin(progress * math.pi * 2);
    canvas.drawLine(
      Offset(-20 + drift * 10, size.height * 0.28),
      Offset(size.width + 20, size.height * 0.12 + drift * 8),
      blue,
    );
    canvas.drawLine(
      Offset(-30, size.height * 0.43 - drift * 7),
      Offset(size.width * 0.84, size.height * 0.24),
      gold,
    );
  }

  void _paintParticles(Canvas canvas, Size size) {
    final paint = Paint();
    const seeds = [
      Offset(0.10, 0.12),
      Offset(0.23, 0.20),
      Offset(0.82, 0.11),
      Offset(0.68, 0.30),
      Offset(0.18, 0.52),
      Offset(0.90, 0.55),
      Offset(0.30, 0.79),
      Offset(0.76, 0.86),
      Offset(0.52, 0.18),
      Offset(0.44, 0.63),
    ];

    for (var i = 0; i < seeds.length; i++) {
      final seed = seeds[i];
      final wave = math.sin((progress * math.pi * 2) + i);
      final x = (seed.dx * size.width) + (wave * 7);
      final y =
          (seed.dy * size.height) + (math.cos(progress * math.pi * 2 + i) * 5);
      final topParticle = y < size.height * 0.54;
      paint.color =
          (i.isEven ? const Color(0xFF2563EB) : const Color(0xFFFACC15))
              .withValues(alpha: topParticle ? 0.11 : 0.07);
      canvas.drawCircle(Offset(x, y), topParticle ? 1.05 : 0.85, paint);
    }
  }

  void _paintGrain(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.018);
    for (var x = 0.0; x < size.width; x += 17) {
      for (var y = 0.0; y < size.height; y += 19) {
        final n = ((x * 13 + y * 7) % 29) / 29;
        if (n > 0.72) {
          canvas.drawCircle(Offset(x + n * 4, y), 0.45, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AtmosphericTexturePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _BoundaryPattern extends StatelessWidget {
  const _BoundaryPattern();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(painter: _BoundaryPatternPainter()),
    );
  }
}

class _BoundaryPatternPainter extends CustomPainter {
  const _BoundaryPatternPainter();

  static const _boundaryStop = 0.471;

  @override
  void paint(Canvas canvas, Size size) {
    final boundaryY = size.height * _boundaryStop;
    final darkPaint = Paint()
      ..color = const Color(0xFF111827).withValues(alpha: 0.18);
    final lightPaint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    final goldPaint = Paint()
      ..color = const Color(0xFFFACC15).withValues(alpha: 0.14);

    for (var x = -8.0; x <= size.width + 8; x += 13) {
      for (var y = boundaryY - 58; y <= boundaryY + 58; y += 13) {
        final distance = (y - boundaryY).abs();
        final fade = (1 - (distance / 64)).clamp(0.0, 1.0);
        if (fade <= 0) continue;

        final isAboveBoundary = y < boundaryY;
        final paint = isAboveBoundary ? darkPaint : lightPaint;
        final radius = isAboveBoundary ? 0.95 : 1.1;

        paint.color = paint.color.withValues(alpha: 0.20 * fade);
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }

    for (var x = 18.0; x <= size.width; x += 34) {
      final offsetY = boundaryY + ((x ~/ 34).isEven ? -10 : 12);
      canvas.drawCircle(Offset(x, offsetY), 1.45, goldPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DotPattern extends StatelessWidget {
  const _DotPattern({required this.color, required this.alpha});

  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(52, 72),
      painter: _DotPatternPainter(color: color, alpha: alpha),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  const _DotPatternPainter({required this.color, required this.alpha});

  final Color color;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: alpha);
    for (var x = 0.0; x <= size.width; x += 10) {
      for (var y = 0.0; y <= size.height; y += 10) {
        canvas.drawCircle(Offset(x, y), 1.05, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CircleOutline extends StatelessWidget {
  const _CircleOutline({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
    );
  }
}

class _LoginBrandHero extends StatelessWidget {
  const _LoginBrandHero({
    required this.logoSize,
    required this.wordmarkWidth,
    required this.subtitleSize,
    required this.compact,
  });

  final double logoSize;
  final double wordmarkWidth;
  final double subtitleSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.16),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.50),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/img_text/elecom_black.png',
                width: wordmarkWidth,
                fit: BoxFit.contain,
                color: const Color(0xFF111827),
              ),
            ),
            SizedBox(height: compact ? 7 : 9),
            Text(
              'Secure Digital Campus Election System',
              style: GoogleFonts.poppins(
                color: const Color(0xFF111827).withValues(alpha: 0.64),
                fontWeight: FontWeight.w600,
                fontSize: subtitleSize - 0.5,
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 760.ms)
        .slideY(
          begin: -0.06,
          end: 0,
          duration: 760.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
