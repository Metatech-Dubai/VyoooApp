/// Contract for auth. Replace with real API implementation.
abstract class AuthService {
  Future<AuthResult> login({
    required String username,
    required String password,
    bool rememberMe = false,
  });
}

class AuthResult {
  const AuthResult({required this.success, this.errorMessage});

  final bool success;
  final String? errorMessage;
}
