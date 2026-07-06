import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/services/media_push_service.dart';

void main() {
  group('MediaPushService gating', () {
    test('is disabled by default — no live push in this pass', () {
      // start()/stop() short-circuit on `if (!enabled) ...`, so a false flag means
      // the service can never push a stream live until explicitly enabled.
      expect(MediaPushService.enabled, isFalse);
    });
  });

  group('cloudflareHlsUrl pure helper', () {
    test('builds the expected HLS manifest URL', () {
      expect(
        MediaPushService.cloudflareHlsUrl('vid123'),
        'https://videodelivery.net/vid123/manifest/video.m3u8',
      );
    });
    test('trims whitespace in the id', () {
      expect(
        MediaPushService.cloudflareHlsUrl('  vid123 '),
        'https://videodelivery.net/vid123/manifest/video.m3u8',
      );
    });
  });
}
