import 'package:flutter/foundation.dart';
import '../../core/services/auth_service.dart';

class LoginProvider extends ChangeNotifier {
  AuthService? _authService;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuperAdmin = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSuperAdmin => _isSuperAdmin;

  final String defaultEmail = 'zpx736312737@126.com';
  final String defaultPassword = '';

  void setAuthService(AuthService service) {
    _authService = service;
  }

  String? validateEmail(String value) {
    if (value.isEmpty) return '请输入邮箱';
    return null;
  }

  String? validatePassword(String value) {
    if (value.isEmpty) return '请输入密码';
    return null;
  }

  Future<bool> signIn(String email, String password) async {
    if (_authService == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService!.signIn(email, password);
      _isSuperAdmin = await _authService!.checkSuperAdmin(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = '登录失败: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService?.signOut();
    _isSuperAdmin = false;
    notifyListeners();
  }
}
