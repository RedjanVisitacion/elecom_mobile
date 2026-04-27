import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/notifications/notification_center_store.dart';
import '../../elecom/profile/elecom_terms_conditions_screen.dart';
import '../../elecom/presentation/elecom_dashboard.dart';
import '../state/login_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _termsShownOnce = false;

  Future<void> _showTerms() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.94,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: const ElecomTermsConditionsScreen(),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final vm = context.read<LoginViewModel>();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (!vm.acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms & Conditions'),
        ),
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

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const ElecomDashboard(),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      final msg = vm.error ?? 'Login failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  void dispose() {
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
        data: MediaQuery.of(context).copyWith(
          platformBrightness: Brightness.light,
        ),
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/gif/Elecom Splash.gif',
                            height: 88,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'WELCOME',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _RoundedField(
                            controller: _studentIdController,
                            hintText: 'STUDENT ID',
                            keyboardType: TextInputType.text,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter your student id';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _RoundedField(
                            controller: _passwordController,
                            hintText: 'PASSWORD',
                            obscureText: vm.obscurePassword,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                            suffix: IconButton(
                              onPressed: () => vm.togglePasswordVisibility(),
                              icon: Icon(
                                vm.obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: vm.isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: 0,
                              ),
                              child: vm.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'LOGIN',
                                      style: TextStyle(fontWeight: FontWeight.w800),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Checkbox(
                                value: vm.acceptedTerms,
                                onChanged: (v) async {
                                  final next = v ?? false;
                                  if (next && !vm.acceptedTerms && !_termsShownOnce) {
                                    _termsShownOnce = true;
                                    await _showTerms();
                                    if (!mounted) return;
                                    vm.setAcceptedTerms(true);
                                    return;
                                  }
                                  vm.setAcceptedTerms(next);
                                },
                                activeColor: Colors.black,
                              ),
                              Flexible(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text('I accept the '),
                                    InkWell(
                                      onTap: _showTerms,
                                      child: const Text(
                                        'Terms & Conditions',
                                        style: TextStyle(
                                          color: Color(0xFF6C63FF),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              'FORGOT PASSWORD?',
                              style: TextStyle(
                                color: Color(0xFF6C63FF),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
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
        ),
      ),
    );
  }
}

class _RoundedField extends StatelessWidget {
  const _RoundedField({
    required this.controller,
    required this.hintText,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String hintText;
  final String? Function(String?) validator;
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
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: const Color(0xFFE6E6E6),
        hintStyle: const TextStyle(
          color: Color(0xFF9E9E9E),
          fontWeight: FontWeight.w700,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
          borderSide: const BorderSide(color: Colors.black12),
        ),
      ),
    );
  }
}
