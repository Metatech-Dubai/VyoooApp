import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/models/reel_media_item.dart';

void main() {
  group('ReelMediaItem.streamThumbnailFromVideoUrl', () {
    test('builds a poster URL for Cloudflare Stream playback', () {
      expect(
        ReelMediaItem.streamThumbnailFromVideoUrl(
          'https://videodelivery.net/abc123/manifest/video.m3u8',
        ),
        'https://videodelivery.net/abc123/thumbnails/thumbnail.jpg',
      );
      expect(
        ReelMediaItem.streamThumbnailFromVideoUrl(
          'https://customer-example.cloudflarestream.com/abc123/manifest/video.m3u8',
        ),
        'https://videodelivery.net/abc123/thumbnails/thumbnail.jpg',
      );
    });

    test('leaves R2 original files alone', () {
      expect(
        ReelMediaItem.streamThumbnailFromVideoUrl(
          'https://video.vyooo.app/vr/user/clip.mp4',
        ),
        '',
      );
    });
  });

  group('ReelMediaItem.listFromPost', () {
    test('keeps the stored poster for an R2 video', () {
      final items = ReelMediaItem.listFromPost({
        'mediaType': 'video',
        'videoUrl': 'https://video.vyooo.app/vr/user/clip.mp4',
        'thumbnailUrl': 'https://video.vyooo.app/vr/user/clip.jpg',
      });
      expect(items, hasLength(1));
      expect(items.single.thumbnailUrl, 'https://video.vyooo.app/vr/user/clip.jpg');
    });
  });
}
