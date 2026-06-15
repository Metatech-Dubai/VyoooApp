import 'dart:async';
import 'reserved_usernames.dart';
import 'username_service.dart';

/// Mock implementation for development. Replace with real API client later.
class MockUsernameService implements UsernameService {
  @override
  Future<UsernameCheckResult> checkAvailability(String username) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (ReservedUsernames.isReserved(username)) {
      return UsernameCheckResult(
        available: false,
        isReserved: true,
        suggestions: const [],
      );
    }
    const taken = {'takenuser', 'existing'};
    final available = !taken.contains(username.toLowerCase());
    final suggestions = available
        ? <String>[]
        : <String>[
            '${username}_official',
            '${username}123',
            'the_$username',
            '${username}_app',
          ];
    return UsernameCheckResult(available: available, suggestions: suggestions);
  }

  @override
  Stream<UsernameCheckResult> watchAvailability(
    String username, {
    required String excludeUid,
  }) async* {
    yield await checkAvailability(username);
  }
}
