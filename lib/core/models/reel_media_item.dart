/// One media entry of a (possibly multi-media / carousel) post.
///
/// Firestore schema (`reels/{id}.mediaItems[]`, additive — older posts only
/// have the flat `mediaType` / `imageUrl` / `videoUrl` / `thumbnailUrl`
/// fields, which always mirror the **first** item for backward compatibility):
/// ```
/// mediaItems: [
///   { type: 'image'|'video', url: '…', thumbnailUrl: '…' },
/// ]
/// mediaCount: 2
/// ```
class ReelMediaItem {
  const ReelMediaItem({
    required this.type,
    required this.url,
    this.thumbnailUrl = '',
  });

  /// `'image'` or `'video'`.
  final String type;
  final String url;
  final String thumbnailUrl;

  bool get isVideo => type == 'video';

  Map<String, dynamic> toMap() => {
        'type': type,
        'url': url,
        'thumbnailUrl': thumbnailUrl,
      };

  /// Validates one raw Firestore/cache entry. Returns null for anything that
  /// is not a map with a known type and an absolute media URL.
  static ReelMediaItem? fromRaw(dynamic raw) {
    if (raw is! Map) return null;
    final type = (raw['type']?.toString() ?? '').trim().toLowerCase();
    if (type != 'image' && type != 'video') return null;
    final url = (raw['url']?.toString() ?? '').trim();
    if (url.isEmpty || Uri.tryParse(url)?.isAbsolute != true) return null;
    final thumb = (raw['thumbnailUrl']?.toString() ?? '').trim();
    return ReelMediaItem(type: type, url: url, thumbnailUrl: thumb);
  }

  /// Parses a raw `mediaItems` list, dropping invalid entries.
  static List<ReelMediaItem> listFromRaw(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map(fromRaw)
        .whereType<ReelMediaItem>()
        .toList(growable: false);
  }

  /// Sanitized plain-map form of a raw `mediaItems` list, safe to keep inside
  /// in-memory reel maps, payloads and JSON caches.
  static List<Map<String, dynamic>> sanitizedRawList(dynamic raw) {
    return listFromRaw(raw).map((e) => e.toMap()).toList(growable: false);
  }

  /// All media of a normalized post/reel map. Uses `mediaItems` when present,
  /// otherwise falls back to the legacy single-media fields so old posts keep
  /// rendering exactly one item.
  static List<ReelMediaItem> listFromPost(Map<String, dynamic> post) {
    final parsed = listFromRaw(post['mediaItems']);
    if (parsed.isNotEmpty) return parsed;

    final mediaType = (post['mediaType']?.toString() ?? '').toLowerCase();
    final imageUrl = (post['imageUrl']?.toString() ?? '').trim();
    final videoUrl = (post['videoUrl']?.toString() ?? '').trim();
    final thumbnailUrl = (post['thumbnailUrl']?.toString() ?? '').trim();

    if (mediaType == 'image' || (videoUrl.isEmpty && imageUrl.isNotEmpty)) {
      final url = imageUrl.isNotEmpty ? imageUrl : thumbnailUrl;
      if (url.isEmpty) return const [];
      return [ReelMediaItem(type: 'image', url: url, thumbnailUrl: url)];
    }
    if (videoUrl.isEmpty) return const [];
    return [
      ReelMediaItem(
        type: 'video',
        url: videoUrl,
        thumbnailUrl: thumbnailUrl.isNotEmpty
            ? thumbnailUrl
            : streamThumbnailFromVideoUrl(videoUrl),
      ),
    ];
  }

  /// Cloudflare Stream poster frame for an HLS playback URL ('' otherwise).
  static String streamThumbnailFromVideoUrl(String videoUrl) {
    if (videoUrl.isEmpty) return '';
    try {
      final uri = Uri.parse(videoUrl);
      final videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (videoId.isEmpty) return '';
      return 'https://videodelivery.net/$videoId/thumbnails/thumbnail.jpg';
    } catch (_) {
      return '';
    }
  }
}
