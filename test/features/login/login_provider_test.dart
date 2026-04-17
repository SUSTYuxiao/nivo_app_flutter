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
  });
}
