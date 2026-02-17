/// Result of find account request.
class FindAccountResult {
  const FindAccountResult({required this.found, this.errorMessage});

  final bool found;
  final String? errorMessage;
}

/// Contract for find account (forgot password). Replace with real API.
abstract class FindAccountService {
  Future<FindAccountResult> findAccount(String emailOrUsername);
}
