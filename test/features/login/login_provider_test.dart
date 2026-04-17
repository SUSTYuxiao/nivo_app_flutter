import 'package:flutter_test/flutter_test.dart';
import 'package:nivo_app/features/login/login_provider.dart';

void main() {
  group('LoginProvider', () {
    test('initial state is not loading and not logged in', () {
      final provider = LoginProvider();
      expect(provider.isLoading, false);
      expect(provider.errorMessage, isNull);
      expect(provider.isSuperAdmin, false);
    });

    test('validates empty email', () {
      final provider = LoginProvider();
      expect(provider.validateEmail(''), '请输入邮箱');
    });

    test('validates empty password', () {
      final provider = LoginProvider();
      expect(provider.validatePassword(''), '请输入密码');
    });

    test('accepts valid email', () {
      final provider = LoginProvider();
      expect(provider.validateEmail('test@test.com'), isNull);
    });

    test('signIn when _authService is null returns false immediately', () async {
      final provider = LoginProvider();
      // Do NOT call setAuthService — _authService stays null
      final result = await provider.signIn('test@test.com', 'password');
      expect(result, false);
      // Should not have set isLoading or errorMessage
      expect(provider.isLoading, false);
      expect(provider.errorMessage, isNull);
    });

    test('signOut resets isSuperAdmin to false', () async {
      final provider = LoginProvider();
      // Directly call signOut without authService — should still reset state
      await provider.signOut();
      expect(provider.isSuperAdmin, false);
    });
  });
}
