/// Resolves HLS / MP4 fallback URLs for Cloudflare Stream playback.
///
/// Ported from the 360 VOD feature (`feature/360-video-integration`) so the live
/// viewer resolves the same URL candidates. Self-contained (inline URL check) to
/// avoid pulling the feed-upload utilities.
class StreamPlaybackUrls {
  StreamPlaybackUrls._();

  static bool isPlayableUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    return uri.scheme == 'https' || uri.scheme == 'http';
  }

  static List<String> candidates(String raw) {
    final url = raw.trim();
    if (!isPlayableUrl(url)) return const [];
    final out = <String>[url];
    final m = RegExp(
      r'^(https?:\/\/[^/]+)\/([^/]+)\/manifest\/video\.m3u8$',
      caseSensitive: false,
    ).firstMatch(url);
    if (m != null) {
      final hostBase = m.group(1)!;
      final videoId = m.group(2)!;
      final mp4 = '$hostBase/$videoId/downloads/default.mp4';
      if (isPlayableUrl(mp4)) out.add(mp4);
      final hlsFallback = 'https://videodelivery.net/$videoId/manifest/video.m3u8';
      final mp4Fallback = 'https://videodelivery.net/$videoId/downloads/default.mp4';
      if (isPlayableUrl(hlsFallback)) out.add(hlsFallback);
      if (isPlayableUrl(mp4Fallback)) out.add(mp4Fallback);
    }
    return out.toSet().toList();
  }

  /// Same URLs as [candidates], but MP4 progressive sources first for native
  /// 360 players (ExoPlayer / AVPlayer) that handle them more reliably than HLS.
  static List<String> candidatesPreferMp4(String raw) {
    final all = candidates(raw);
    all.sort((a, b) {
      final aMp4 = _isMp4Url(a);
      final bMp4 = _isMp4Url(b);
      if (aMp4 == bMp4) return 0;
      return aMp4 ? -1 : 1;
    });
    return all;
  }

  static bool _isMp4Url(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mp4') || lower.contains('/downloads/');
  }
}
