import 'package:flutter/material.dart';

import '../../../core/notifications/local_push_service.dart';
import '../../../core/notifications/notification_center_store.dart';
import '../../../core/session/notification_preferences.dart';
import '../data/elecom_mobile_api.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final ElecomMobileApi _api = ElecomMobileApi();
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _submitting = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() {
      _submitting = true;
    });

    try {
      await _api.changePassword(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (!mounted) return;

      final inAppEnabled = await NotificationPreferences.isInAppEnabled();
      final pushEnabled = await NotificationPreferences.isPushEnabled();
      const notifTitle = 'Password Updated';
      const notifBody = 'Your account password was changed successfully.';

      // Always persist to the backend so notifications are per-account.
      await NotificationCenterStore.add(
        title: notifTitle,
        body: notifBody,
      );

      if (pushEnabled) {
        await LocalPushService.show(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: notifTitle,
          body: notifBody,
        );
      }

      if (!mounted) return;

      if (inAppEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(notifBody)),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to change password. Please check your old password.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? const Color(0xFF2A2A35) : Colors.white;
    final borderColor = isDarkMode ? Colors.white12 : Colors.black12;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Change Password',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: titleColor,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _PasswordField(
                controller: _oldPasswordController,
                label: 'Old Password',
                obscureText: _obscureOld,
                onToggle: () => setState(() => _obscureOld = !_obscureOld),
                cardColor: cardColor,
                borderColor: borderColor,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter old password';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _PasswordField(
                controller: _newPasswordController,
                label: 'New Password',
                obscureText: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                cardColor: cardColor,
                borderColor: borderColor,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter new password';
                  if (value.length < 8) return 'New password must be at least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _PasswordField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                obscureText: _obscureConfirm,
                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                cardColor: cardColor,
                borderColor: borderColor,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please confirm new password';
                  if (value != _newPasswordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? Colors.white : Colors.black,
                    foregroundColor: isDarkMode ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDarkMode ? Colors.black : Colors.white,
                          ),
                        )
                      : const Text(
                          'Change Password',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.onToggle,
    required this.cardColor,
    required this.borderColor,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final VoidCallback onToggle;
  final Color cardColor;
  final Color borderColor;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
        filled: true,
        fillColor: cardColor,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDarkMode ? Colors.white38 : Colors.black38),
        ),
      ),
    );
  }
}
