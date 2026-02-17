/// Validation rules for username input.
/// Kept separate from UI and API.
class UsernameValidation {
  UsernameValidation._();

  /// Minimum length to trigger API check.
  static const int minLengthForCheck = 3;

  /// Allowed pattern: letters, numbers, underscore only.
  static final RegExp _allowedPattern = RegExp(r'^[a-z0-9_]*$');

  /// Normalizes input: lowercase, no spaces.
  static String normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'\s'), '');
  }

  /// Whether [input] is valid for display/API (length and pattern).
  static bool isValidFormat(String input) {
    final normalized = normalize(input);
    return normalized.length >= minLengthForCheck && _allowedPattern.hasMatch(normalized);
  }

  /// Whether [input] has at least [minLengthForCheck] chars and valid pattern.
  static bool shouldCheckAvailability(String input) {
    return isValidFormat(input);
  }
}
