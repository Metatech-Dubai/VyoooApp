import 'hashtag_utils.dart';

/// Builds at least [minCount] normalized tag strings for the upload flow.
/// Replace or extend with an AI/backend call later; keep output aligned with
/// [HashtagUtils.normalizeForQuery] rules.
class UploadTagSuggestions {
  UploadTagSuggestions._();

  static const int defaultMinCount = 30;

  static final Map<String, List<String>> _byCategory = {
    'Entertainment': [
      'entertainment',
      'fun',
      'viral',
      'trending',
      'fyp',
      'foryou',
      'reels',
      'shorts',
      'watch',
      'daily',
      'lifestyle',
      'creator',
      'content',
      'explore',
      'vyooo',
      'show',
      'clips',
      'moments',
      'vibes',
      'energy',
      'smile',
    ],
    'Education': [
      'education',
      'learn',
      'learning',
      'study',
      'tips',
      'howto',
      'tutorial',
      'knowledge',
      'skills',
      'facts',
      'explained',
      'guide',
      'student',
      'teacher',
      'productivity',
      'growth',
      'mindset',
      'motivation',
      'vyooo',
      'wisdom',
    ],
    'Travel': [
      'travel',
      'wanderlust',
      'adventure',
      'trip',
      'vacation',
      'explore',
      'nature',
      'landscape',
      'journey',
      'destination',
      'world',
      'sky',
      'ocean',
      'mountains',
      'city',
      'culture',
      'foodie_travel',
      'vyooo',
      'travelgram',
      'outdoors',
    ],
    'Sports': [
      'sports',
      'fitness',
      'training',
      'game',
      'athlete',
      'workout',
      'team',
      'win',
      'motivation',
      'active',
      'health',
      'run',
      'gym',
      'competition',
      'highlight',
      'score',
      'vyooo',
      'sportslife',
      'fans',
    ],
    'Music': [
      'music',
      'song',
      'artist',
      'beat',
      'sound',
      'audio',
      'live',
      'concert',
      'dance',
      'vibes',
      'playlist',
      'newmusic',
      'cover',
      'remix',
      'producer',
      'vyooo',
      'musician',
      'performance',
      'studio',
    ],
    'Comedy': [
      'comedy',
      'funny',
      'humor',
      'lol',
      'jokes',
      'skit',
      'meme',
      'viral',
      'laugh',
      'entertainment',
      'fyp',
      'reels',
      'comedyreels',
      'relatable',
      'vyooo',
      'funnyvideos',
      'humour',
      'comedian',
      'parody',
    ],
    'Fashion': [
      'fashion',
      'style',
      'outfit',
      'ootd',
      'trend',
      'look',
      'aesthetic',
      'streetwear',
      'model',
      'beauty',
      'accessories',
      'design',
      'vyooo',
      'fashionista',
      'chic',
      'wardrobe',
      'runway',
      'inspo',
    ],
    'Food': [
      'food',
      'foodie',
      'recipe',
      'cooking',
      'yummy',
      'delicious',
      'kitchen',
      'eat',
      'chef',
      'tasty',
      'homemade',
      'restaurant',
      'snack',
      'vyooo',
      'foodlover',
      'dinner',
      'lunch',
      'brunch',
    ],
    'Technology': [
      'technology',
      'tech',
      'gadget',
      'innovation',
      'ai',
      'coding',
      'software',
      'hardware',
      'review',
      'future',
      'digital',
      'startup',
      'vyooo',
      'engineering',
      'science',
      'electronics',
      'tips',
      'tutorial',
    ],
    'Other': [
      'vyooo',
      'creator',
      'content',
      'community',
      'daily',
      'life',
      'moments',
      'share',
      'explore',
      'trending',
      'fyp',
      'foryou',
      'reels',
      'viral',
      'vibes',
      'story',
      'world',
      'people',
      'culture',
    ],
  };

  static const List<String> _genericFill = [
    'vyooo',
    'fyp',
    'foryou',
    'viral',
    'trending',
    'reels',
    'explore',
    'creator',
    'content',
    'daily',
    'vibes',
    'moments',
    'watch',
    'share',
    'community',
    'discover',
    'new',
    'original',
    'quality',
    'aesthetic',
    'lifestyle',
    'world',
    'culture',
    'people',
    'story',
    'clip',
    'shortform',
    'video',
    'mobile',
    'social',
    'feed',
    'grow',
    'support',
    'love',
    'best',
    'top',
    'mustwatch',
    '2026',
  ];

  /// Returns at least [minCount] unique normalized tags (order: title tokens,
  /// category pack, then generic fill).
  static List<String> build({
    required String title,
    String? category,
    int minCount = defaultMinCount,
  }) {
    final out = <String>[];
    final seen = <String>{};

    void add(String raw) {
      final n = HashtagUtils.normalizeForQuery(raw);
      if (n.isEmpty || seen.contains(n)) return;
      seen.add(n);
      out.add(n);
    }

    for (final w in _titleWords(title)) {
      add(w);
    }

    final cat = category?.trim();
    if (cat != null && cat.isNotEmpty) {
      for (final t in _byCategory[cat] ?? _byCategory['Other']!) {
        add(t);
      }
    } else {
      for (final t in _byCategory['Other']!) {
        add(t);
      }
    }

    var i = 0;
    while (out.length < minCount && i < 200) {
      final base = _genericFill[i % _genericFill.length];
      final candidate = i < _genericFill.length ? base : '${base}_${i ~/ _genericFill.length}';
      add(candidate);
      i++;
    }

    return out.take(minCount).toList();
  }

  static Iterable<String> _titleWords(String title) sync* {
    final parts = title.toLowerCase().split(RegExp(r'[^a-z0-9]+'));
    for (final p in parts) {
      final t = p.trim();
      if (t.length < 2) continue;
      if (t.length > 32) continue;
      yield t;
    }
  }
}
