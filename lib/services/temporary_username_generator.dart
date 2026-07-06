import 'reserved_usernames.dart';
import 'username_service.dart';
import 'username_validation.dart';

/// Assigns a non-reserved username when the user requested a reserved handle.
class TemporaryUsernameGenerator {
  TemporaryUsernameGenerator._();

  static String baseFromUid(String uid) {
    final cleaned = uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final tail = cleaned.length >= 8
        ? cleaned.substring(cleaned.length - 8)
        : cleaned.padLeft(8, '0');
    return UsernameValidation.normalize('user_$tail');
  }

  static Future<String> generate({
    required String uid,
    required UsernameService usernameService,
  }) async {
    final base = baseFromUid(uid);
    var candidate = base;
    for (var i = 0; i < 20; i++) {
      if (!ReservedUsernames.isReserved(candidate) &&
          UsernameValidation.isValidFormat(candidate)) {
        final result = await usernameService.checkAvailability(candidate);
        if (result.available) return candidate;
      }
      candidate = UsernameValidation.normalize('${base}_$i');
    }
    return base;
  }
}
