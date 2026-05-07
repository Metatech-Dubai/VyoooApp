/// Normalization and matching for hashtags (aligned with upload tag rules).
class HashtagUtils {
  HashtagUtils._();

  static final RegExp _captionHashtagPattern = RegExp(
    r'#[^\s#]+',
    unicode: true,
  );

  /// Lowercase, strip `#`, keep [a-z0-9_]; matches [UploadDetailsScreen] tag rules.
  static String normalizeForQuery(String raw) {
    var s = raw.trim();
    if (s.startsWith('#')) {
      s = s.substring(1).trimLeft();
    }
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_ ]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  /// Whether [caption] contains a #token that normalizes to [normalizedTag].
  static bool captionContainsHashtag(String caption, String normalizedTag) {
    if (normalizedTag.isEmpty) return false;
    for (final m in _captionHashtagPattern.allMatches(caption)) {
      final token = m.group(0);
      if (token == null || token.length < 2) continue;
      if (normalizeForQuery(token) == normalizedTag) return true;
    }
    return false;
  }

  static List<String> _tagsFromReel(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => normalizeForQuery(e.toString()))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// True if structured [tags] or [caption] references this hashtag.
  static bool matchesCaptionOrTags({
    required String caption,
    required List<String> tags,
    required String normalizedTag,
  }) {
    if (normalizedTag.isEmpty) return false;
    if (tags.contains(normalizedTag)) return true;
    return captionContainsHashtag(caption, normalizedTag);
  }

  static bool reelMapMatchesHashtag(
    Map<String, dynamic> reel,
    String normalizedTag,
  ) {
    if (normalizedTag.isEmpty) return false;
    final caption = (reel['caption'] as String?) ?? '';
    final tagList = _tagsFromReel(reel['tags']);
    return matchesCaptionOrTags(
      caption: caption,
      tags: tagList,
      normalizedTag: normalizedTag,
    );
  }
}
