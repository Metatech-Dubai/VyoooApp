/// Short optional label shown on profile grid tiles.
abstract final class ProfileGridTitle {
  ProfileGridTitle._();

  static const int maxLength = 15;

  static String fromReel(Map<String, dynamic> reel) {
    return _clamp((reel['profileGridTitle'] as String? ?? '').trim());
  }

  static String normalizeForSave(String raw) {
    return _clamp(raw.trim());
  }

  static String _clamp(String value) {
    if (value.isEmpty) return '';
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }
}
