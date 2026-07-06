import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/utils/reel_engagement.dart';

void main() {
  group('ReelEngagement.isMainFeedEligible', () {
    test('excludes VR and 360 reels from main feed', () {
      expect(
        ReelEngagement.isMainFeedEligible({'isVR': true, 'videoUrl': 'https://x/v.mp4'}),
        isFalse,
      );
      expect(
        ReelEngagement.isMainFeedEligible({
          'is360Video': true,
          'videoUrl': 'https://x/v.mp4',
        }),
        isFalse,
      );
      expect(
        ReelEngagement.isMainFeedEligible({'videoUrl': 'https://x/v.mp4'}),
        isTrue,
      );
    });

    test('excludes repost stubs from main feed', () {
      expect(
        ReelEngagement.isMainFeedEligible({
          'isRepost': true,
          'videoUrl': 'https://x/v.mp4',
        }),
        isFalse,
      );
    });
  });
}
