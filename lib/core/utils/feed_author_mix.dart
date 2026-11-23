/// Spreads a ranked reel list across accounts.
///
/// Input order is preserved inside each account. Accounts are visited in the
/// order their first reel appears, one reel at a time, so one upload burst
/// cannot fill the whole feed.
abstract final class FeedAuthorMix {
  FeedAuthorMix._();

  static String authorKey(Map<String, dynamic> reel) {
    final uid = (reel['userId'] as String?)?.trim() ?? '';
    if (uid.isNotEmpty) return uid;
    final id = (reel['id'] as String?)?.trim() ?? '';
    return id.isEmpty ? '' : 'reel:$id';
  }

  static List<Map<String, dynamic>> interleave(
    List<Map<String, dynamic>> reels, {
    int? limit,
  }) {
    if (reels.isEmpty) return const [];
    final cap = limit == null || limit < 0 ? reels.length : limit;
    if (cap == 0) return const [];

    final buckets = <String, List<Map<String, dynamic>>>{};
    final authorOrder = <String>[];
    for (final reel in reels) {
      final key = authorKey(reel);
      final bucket = buckets.putIfAbsent(key, () {
        authorOrder.add(key);
        return <Map<String, dynamic>>[];
      });
      bucket.add(reel);
    }

    if (authorOrder.length < 2) {
      final only = buckets[authorOrder.first]!;
      if (only.length <= cap) return List<Map<String, dynamic>>.from(only);
      return only.take(cap).toList(growable: false);
    }

    final out = <Map<String, dynamic>>[];
    var remaining = true;
    while (remaining && out.length < cap) {
      remaining = false;
      for (final key in authorOrder) {
        final bucket = buckets[key]!;
        if (bucket.isEmpty) continue;
        out.add(bucket.removeAt(0));
        if (bucket.isNotEmpty) remaining = true;
        if (out.length >= cap) break;
      }
    }
    return out;
  }
}
