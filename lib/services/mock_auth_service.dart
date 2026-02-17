import 'auth_service.dart';

/// Mock implementation for development. Replace with real auth API.
class MockAuthService implements AuthService {
  @override
  Future<AuthResult> login({
    required String username,
    required String password,
    bool rememberMe = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (username.isEmpty || password.isEmpty) {
      return const AuthResult(success: false, errorMessage: 'Please fill all fields');
    }
    return const AuthResult(success: true);
  }
}
