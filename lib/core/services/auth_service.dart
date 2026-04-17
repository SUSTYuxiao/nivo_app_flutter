import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import '../constants.dart';

class AuthService {
  final _supabase = Supabase.instance.client;
  final _dio = Dio(BaseOptions(baseUrl: apiBaseUrl));

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;
  bool get isLoggedIn => currentUser != null;

  Future<AuthResponse> signIn(String email, String password) {
    return _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _supabase.auth.signOut();

  Future<bool> checkSuperAdmin(String email) async {
    final response =
        await _dio.post('/auth/checkSuperAdmin', data: {'email': email});
    final body = response.data;
    if (body is Map && body['code'] == 200) {
      return body['data'] == true;
    }
    return false;
  }
}
