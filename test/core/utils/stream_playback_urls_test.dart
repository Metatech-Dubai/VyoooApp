import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/utils/stream_playback_urls.dart';

void main() {
  group('isPlayableUrl', () {
    test('accepts http/https', () {
      expect(StreamPlaybackUrls.isPlayableUrl('https://videodelivery.net/x/manifest/video.m3u8'), isTrue);
      expect(StreamPlaybackUrls.isPlayableUrl('http://a.b/c.mp4'), isTrue);
    });
    test('rejects empty / non-url / non-http scheme', () {
      expect(StreamPlaybackUrls.isPlayableUrl(''), isFalse);
      expect(StreamPlaybackUrls.isPlayableUrl('   '), isFalse);
      expect(StreamPlaybackUrls.isPlayableUrl('not a url'), isFalse);
      expect(StreamPlaybackUrls.isPlayableUrl('ftp://a.b/c'), isFalse);
    });
  });

  group('candidates', () {
    test('non-manifest url returns just itself', () {
      final c = StreamPlaybackUrls.candidates('https://cdn.example.com/live/x.m3u8');
      expect(c, ['https://cdn.example.com/live/x.m3u8']);
    });

    test('empty for invalid url', () {
      expect(StreamPlaybackUrls.candidates(''), isEmpty);
      expect(StreamPlaybackUrls.candidates('nonsense'), isEmpty);
    });

    test('cloudflare manifest expands to MP4 + fallbacks', () {
      final c = StreamPlaybackUrls.candidates(
          'https://customer-abc.cloudflarestream.com/vid123/manifest/video.m3u8');
      // Original + host mp4 + videodelivery hls + videodelivery mp4, de-duplicated.
      expect(c, contains('https://customer-abc.cloudflarestream.com/vid123/manifest/video.m3u8'));
      expect(c, contains('https://customer-abc.cloudflarestream.com/vid123/downloads/default.mp4'));
      expect(c, contains('https://videodelivery.net/vid123/manifest/video.m3u8'));
      expect(c, contains('https://videodelivery.net/vid123/downloads/default.mp4'));
    });

    test('de-duplicates identical entries', () {
      final c = StreamPlaybackUrls.candidates(
          'https://videodelivery.net/vid123/manifest/video.m3u8');
      // The original equals the videodelivery hls fallback — should appear once.
      final count = c.where((u) => u == 'https://videodelivery.net/vid123/manifest/video.m3u8').length;
      expect(count, 1);
    });
  });

  group('candidatesPreferMp4', () {
    test('MP4 sources are ordered before HLS', () {
      final c = StreamPlaybackUrls.candidatesPreferMp4(
          'https://customer-abc.cloudflarestream.com/vid123/manifest/video.m3u8');
      final firstMp4 = c.indexWhere((u) => u.contains('.mp4') || u.contains('/downloads/'));
      final firstHls = c.indexWhere((u) => u.endsWith('.m3u8'));
      expect(firstMp4, isNonNegative);
      expect(firstHls, isNonNegative);
      expect(firstMp4, lessThan(firstHls));
    });
  });
}
