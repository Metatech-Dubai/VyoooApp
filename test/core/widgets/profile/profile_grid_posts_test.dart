import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/widgets/profile/profile_grid_posts.dart';

void main() {
  group('ProfileGridPosts.filterForPostsTab', () {
    test('excludes VR and 360 reels from Posts tab', () {
      final reels = [
        {
          'mediaType': 'video',
          'videoUrl': 'https://videodelivery.net/abc/manifest/video.m3u8',
          'isVR': true,
        },
        {
          'mediaType': 'video',
          'videoUrl': 'https://videodelivery.net/def/manifest/video.m3u8',
          'is360Video': true,
          'projectionType': 'equirectangular',
        },
        {
          'mediaType': 'video',
          'videoUrl': 'https://videodelivery.net/ghi/manifest/video.m3u8',
          'isVR': false,
        },
        {
          'mediaType': 'image',
          'imageUrl': 'https://example.com/photo.jpg',
        },
      ];

      final posts = ProfileGridPosts.filterForPostsTab(reels);

      expect(posts.length, 2);
      expect(posts.every((r) => !ProfileGridPosts.belongsInVrTab(r)), isTrue);
    });
  });
}
