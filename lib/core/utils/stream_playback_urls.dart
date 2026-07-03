import 'video_upload_policy.dart';

/// Resolves HLS / MP4 fallback URLs for Cloudflare Stream playback.
class StreamPlaybackUrls {
  StreamPlaybackUrls._();

  static List<String> candidates(String raw) {
    final url = raw.trim();
    if (!VideoUploadPolicy.isPlayableUrl(url)) return const [];
    final out = <String>[url];
    final m = RegExp(
      r'^(https?:\/\/[^/]+)\/([^/]+)\/manifest\/video\.m3u8$',
      caseSensitive: false,
    ).firstMatch(url);
    if (m != null) {
      final hostBase = m.group(1)!;
      final videoId = m.group(2)!;
      final mp4 = '$hostBase/$videoId/downloads/default.mp4';
      if (VideoUploadPolicy.isPlayableUrl(mp4)) out.add(mp4);
      final hlsFallback =
          'https://videodelivery.net/$videoId/manifest/video.m3u8';
      final mp4Fallback =
          'https://videodelivery.net/$videoId/downloads/default.mp4';
      if (VideoUploadPolicy.isPlayableUrl(hlsFallback)) out.add(hlsFallback);
      if (VideoUploadPolicy.isPlayableUrl(mp4Fallback)) out.add(mp4Fallback);
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

  /// HLS / manifest URLs first — adaptive streaming starts playback faster
  /// than buffering a full progressive MP4 (important for large 360° sources).
  static List<String> candidatesPreferStreamingStart(String raw) {
    final all = candidates(raw);
    all.sort((a, b) {
      final aStream = _isStreamingUrl(a);
      final bStream = _isStreamingUrl(b);
      if (aStream == bStream) return 0;
      return aStream ? -1 : 1;
    });
    return all;
  }

  static bool _isMp4Url(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mp4') || lower.contains('/downloads/');
  }

  static bool _isStreamingUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') || lower.contains('/manifest/');
  }
}
