/// Semantic-ish comparison for app version strings (e.g. `1.2.9` from pubspec).
abstract final class AppVersionCompare {
  static int compare(String installed, String required) {
    final a = _parse(installed);
    final b = _parse(required);
    if (a == null || b == null) return 0;
    for (var i = 0; i < 3; i++) {
      final diff = a[i] - b[i];
      if (diff != 0) return diff.sign;
    }
    return 0;
  }

  /// `true` when [installed] is strictly older than [minimum].
  static bool isOlderThan(String installed, String minimum) {
    return compare(installed, minimum) < 0;
  }

  static List<int>? _parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final core = trimmed.split(RegExp(r'[+\-\s]')).first;
    final segments = core.split('.');
    if (segments.isEmpty) return null;
    int part(String s) => int.tryParse(s.trim()) ?? 0;
    return [
      part(segments[0]),
      segments.length > 1 ? part(segments[1]) : 0,
      segments.length > 2 ? part(segments[2]) : 0,
    ];
  }
}
