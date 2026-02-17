/// Result of a username availability check.
class UsernameCheckResult {
  const UsernameCheckResult({
    required this.available,
    this.suggestions = const [],
  });

  final bool available;
  final List<String> suggestions;
}

/// Contract for username validation and availability.
/// Implementations handle API calls; UI only consumes results.
abstract class UsernameService {
  /// Checks if [username] is available.
  /// Returns availability and optional suggestions when unavailable.
  /// Only call when username length >= 3 and passes validation.
  Future<UsernameCheckResult> checkAvailability(String username);
}
