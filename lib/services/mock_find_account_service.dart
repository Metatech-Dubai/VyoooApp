import 'find_account_service.dart';

class MockFindAccountService implements FindAccountService {
  @override
  Future<FindAccountResult> findAccount(String emailOrUsername) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final trimmed = emailOrUsername.trim();
    if (trimmed.isEmpty) {
      return const FindAccountResult(found: false, errorMessage: 'Please enter email or username');
    }
    return const FindAccountResult(found: true);
  }
}
