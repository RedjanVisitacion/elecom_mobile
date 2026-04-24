import 'package:flutter/foundation.dart';

import '../../../core/session/user_session.dart';
import '../data/auth_api.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({AuthApi? authApi}) : _authApi = authApi ?? AuthApi();

  final AuthApi _authApi;

  bool _obscurePassword = true;
  bool _acceptedTerms = false;

  bool _isLoading = false;
  String? _error;

  bool get obscurePassword => _obscurePassword;
  bool get acceptedTerms => _acceptedTerms;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void setAcceptedTerms(bool value) {
    _acceptedTerms = value;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<LoginResponse> login({required String studentId, required String password}) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _authApi.login(studentId: studentId, password: password);
      UserSession.setFromResponse({
        'studentId': res.studentId,
        'role': res.role,
        'full_name': res.fullName,
        'name': res.fullName,
      });
      return res;
    } on AuthException catch (e) {
      _error = e.message;
      rethrow;
    } catch (_) {
      _error = 'Login failed';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
