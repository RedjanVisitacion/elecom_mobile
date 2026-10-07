import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/notifications/notification_center_store.dart';
import '../../../core/utils/toast_service.dart';
import '../../../services/tutorial_service.dart';
import '../../elecom/data/elecom_mobile_api.dart';
import '../../elecom/face/face_enrollment_screen.dart';
import '../../elecom/presentation/elecom_dashboard.dart';
import '../../elecom/profile/elecom_terms_conditions_screen.dart';
import 'forgot_password_screen.dart';
import '../state/login_view_model.dart';

const _navy = Color(0xFF0D1B3E);
const _inputInk = Color(0xFF1E293B);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFCBD5E1);
const _gold = Color(0xFFFACC15);
const _goldFocus = Color(0xFFF59E0B);
const _primary = Color(0xFF1D4ED8);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final ElecomMobileApi _mobileApi = ElecomMobileApi();
  bool _loginTutorialScheduled = false;
  Timer? _validationTimer;
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

  Future<void> _maybeStartLoginTutorial() async {
    if (!mounted || _loginTutorialScheduled) return;
    if (!await TutorialPrefs.shouldShowLoginTutorial()) return;
    _loginTutorialScheduled = true;
    if (!mounted) return;
    await TutorialService.showLoginTutorialIfNeeded(context: context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeStartLoginTutorial(),
    );
  }

  @override
  void dispose() {
    _validationTimer?.cancel();
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _openTerms() async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.94,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          child: ElecomTermsConditionsScreen(requireAgreement: true),
        ),
      ),
    );
    if (!mounted) return;
    context.read<LoginViewModel>().setAcceptedTerms(accepted == true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primary,
        ).copyWith(primary: _primary),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            if (MediaQuery.viewInsetsOf(context).bottom == 0)
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _CampusFooter(),
              ),
            SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              24,
                              MediaQuery.viewInsetsOf(context).bottom == 0 &&
                                      constraints.maxHeight >= 600
                                  ? 68
                                  : 24,
                              24,
                              12,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: AutofillGroup(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Semantics(
                                          label: 'USTP Oroquieta and ELECOM',
                                          image: true,
                                          child: Image.asset(
                                            'assets/USTP_ELECOM_ICON_NOBG.png',
                                            height: 132,
                                            fit: BoxFit.contain,
                                            excludeFromSemantics: true,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'LOGIN',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _navy,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        _LoginInput(
                                          key:
                                              ElecomTutorialKeys.loginStudentId,
                                          label: 'Student ID',
                                          hint: 'Enter your Student ID',
                                          controller: _studentIdController,
                                          icon: Icons.badge_outlined,
                                          enabled: !vm.isLoading,
                                          autofillHints: const [
                                            AutofillHints.username,
                                          ],
                                          action: TextInputAction.next,
                                          validator: (value) =>
                                              value == null ||
                                                  value.trim().isEmpty
                                              ? 'Please enter your student ID'
                                              : null,
                                        ),
                                        const SizedBox(height: 16),
                                        _LoginInput(
                                          key: ElecomTutorialKeys.loginPassword,
                                          label: 'Password',
                                          hint: 'Enter your Password',
                                          controller: _passwordController,
                                          icon: Icons.lock_outline_rounded,
                                          enabled: !vm.isLoading,
                                          obscure: vm.obscurePassword,
                                          autofillHints: const [
                                            AutofillHints.password,
                                          ],
                                          action: TextInputAction.done,
                                          onSubmitted: vm.isLoading
                                              ? null
                                              : (_) => _submit(),
                                          validator: (value) =>
                                              value == null || value.isEmpty
                                              ? 'Please enter your password'
                                              : null,
                                          suffix: IconButton(
                                            tooltip: vm.obscurePassword
                                                ? 'Show password'
                                                : 'Hide password',
                                            onPressed: vm.isLoading
                                                ? null
                                                : vm.togglePasswordVisibility,
                                            icon: Icon(
                                              vm.obscurePassword
                                                  ? Icons
                                                        .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              color: _muted,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Checkbox(
                                              semanticLabel:
                                                  'Accept Terms and Conditions',
                                              value: vm.acceptedTerms,
                                              onChanged: vm.isLoading
                                                  ? null
                                                  : (value) =>
                                                        vm.setAcceptedTerms(
                                                          value ?? false,
                                                        ),
                                              activeColor: _navy,
                                              side: const BorderSide(
                                                color: _muted,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                            Expanded(
                                              child: Wrap(
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  const Text(
                                                    'I accept the ',
                                                    style: TextStyle(
                                                      color: _inputInk,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: vm.isLoading
                                                        ? null
                                                        : _openTerms,
                                                    style: TextButton.styleFrom(
                                                      foregroundColor: _navy,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 2,
                                                          ),
                                                      minimumSize: const Size(
                                                        48,
                                                        48,
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Terms and Conditions',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        FilledButton(
                                          key: ElecomTutorialKeys.loginSubmit,
                                          onPressed:
                                              vm.isLoading || !vm.acceptedTerms
                                              ? null
                                              : _submit,
                                          style:
                                              FilledButton.styleFrom(
                                                backgroundColor: _gold,
                                                foregroundColor: _navy,
                                                disabledBackgroundColor:
                                                    _border,
                                                disabledForegroundColor: _muted,
                                                minimumSize: const Size(
                                                  double.infinity,
                                                  52,
                                                ),
                                                elevation: 2,
                                                shadowColor: _navy.withValues(
                                                  alpha: 0.18,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 14,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ).copyWith(
                                                elevation:
                                                    WidgetStateProperty.resolveWith(
                                                      (states) {
                                                        if (states.contains(
                                                          WidgetState.disabled,
                                                        )) {
                                                          return 0;
                                                        }
                                                        if (states.contains(
                                                          WidgetState.pressed,
                                                        )) {
                                                          return 1;
                                                        }
                                                        if (states.contains(
                                                          WidgetState.hovered,
                                                        )) {
                                                          return 3;
                                                        }
                                                        return 2;
                                                      },
                                                    ),
                                              ),
                                          child: vm.isLoading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: _navy,
                                                      ),
                                                )
                                              : const Text(
                                                  'Sign In',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(height: 8),
                                        Center(
                                          child: TextButton(
                                            key: ElecomTutorialKeys.loginForgot,
                                            onPressed: vm.isLoading
                                                ? null
                                                : () => Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const ForgotPasswordScreen(),
                                                    ),
                                                  ),
                                            style: TextButton.styleFrom(
                                              foregroundColor: _primary,
                                              minimumSize: const Size(48, 48),
                                            ),
                                            child: const Text(
                                              'Forgot Password?',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
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
                          SizedBox(
                            height: MediaQuery.viewInsetsOf(context).bottom == 0
                                ? 180 + MediaQuery.viewPaddingOf(context).bottom
                                : 24,
                          ),
                        ],
                      ),
                    ),
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

class _LoginInput extends StatelessWidget {
  const _LoginInput({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    required this.validator,
    required this.enabled,
    required this.autofillHints,
    required this.action,
    this.obscure = false,
    this.suffix,
    this.onSubmitted,
  });
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final String? Function(String?) validator;
  final bool enabled;
  final Iterable<String> autofillHints;
  final TextInputAction action;
  final bool obscure;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    UnderlineInputBorder border(Color color, [double width = 1.2]) =>
        UnderlineInputBorder(
          borderSide: BorderSide(color: color, width: width),
        );
    return Semantics(
      label: label,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        obscureText: obscure,
        autofillHints: autofillHints,
        textInputAction: action,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        autocorrect: false,
        enableSuggestions: !obscure,
        cursorColor: _goldFocus,
        style: const TextStyle(color: _inputInk, fontSize: 14, height: 1.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _muted, fontSize: 14),
          filled: false,
          prefixIcon: Icon(icon, color: _muted, size: 22),
          suffixIcon: suffix,
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 52,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: border(_border),
          enabledBorder: border(_border),
          disabledBorder: border(_border),
          focusedBorder: border(_goldFocus, 1.8),
          errorBorder: border(const Color(0xFFDC2626)),
          focusedErrorBorder: border(const Color(0xFFDC2626), 2),
          errorMaxLines: 2,
        ),
      ),
    );
  }
}

class _CampusFooter extends StatelessWidget {
  const _CampusFooter();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return SizedBox(
      key: const ValueKey('login-campus-footer'),
      height: 180 + bottomInset,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0x140D1B3E),
                BlendMode.srcATop,
              ),
              child: Image.asset(
                'assets/USTP PICS/USTP_Oroquieta_Campus_Entrance-removebg-preview (1).png',
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                cacheWidth: 1000,
              ),
            ),
          ),
          // A soft wash keeps the slate copyright readable over the facade.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 80,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00FFFFFF), Color(0xF2FFFFFF)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12 + bottomInset,
            child: const Text(
              '© 2026 USTP Oroquieta Electoral Commission',
              key: ValueKey('login-copyright'),
              textAlign: TextAlign.center,
              style: TextStyle(color: _inputInk, fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
