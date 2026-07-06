import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/models/video_360_metadata.dart';

void main() {
  group('Video360Projection.parse', () {
    test('parses equirectangular', () {
      expect(
        Video360Projection.parse('equirectangular'),
        Video360Projection.equirectangular,
      );
      expect(
        Video360Projection.parse('  EQUIRECTANGULAR '),
        Video360Projection.equirectangular,
      );
    });
    test('unknown/null defaults to flat', () {
      expect(Video360Projection.parse(null), Video360Projection.flat);
      expect(Video360Projection.parse('cubemap'), Video360Projection.flat);
      expect(Video360Projection.parse('flat'), Video360Projection.flat);
    });
  });

  group('Video360StereoMode.parse', () {
    test('parses variants', () {
      expect(
        Video360StereoMode.parse('top_bottom'),
        Video360StereoMode.topBottom,
      );
      expect(
        Video360StereoMode.parse('top-bottom'),
        Video360StereoMode.topBottom,
      );
      expect(
        Video360StereoMode.parse('side_by_side'),
        Video360StereoMode.sideBySide,
      );
      expect(Video360StereoMode.parse('mono'), Video360StereoMode.mono);
      expect(Video360StereoMode.parse(null), Video360StereoMode.mono);
    });
  });

  group('use360Player decision', () {
    test('true only for 360 + equirectangular', () {
      const m = Video360Metadata(
        is360Video: true,
        projectionType: Video360Projection.equirectangular,
      );
      expect(m.use360Player, isTrue);
    });
    test('false when not 360', () {
      expect(Video360Metadata.flat.use360Player, isFalse);
    });
    test('false when 360 but not equirectangular', () {
      const m = Video360Metadata(
        is360Video: true,
        projectionType: Video360Projection.flat,
      );
      expect(m.use360Player, isFalse);
    });
  });

  group('firestore round-trip', () {
    test('toFirestore writes the reference keys/values', () {
      const m = Video360Metadata(
        is360Video: true,
        projectionType: Video360Projection.equirectangular,
        stereoMode: Video360StereoMode.mono,
      );
      final json = m.toFirestore();
      expect(json['is360Video'], true);
      expect(json['projectionType'], 'equirectangular');
      expect(json['stereoMode'], 'mono');
    });

    test('fromPost reads back the same values', () {
      final m = Video360Metadata.fromPost({
        'is360Video': true,
        'projectionType': 'equirectangular',
        'stereoMode': 'mono',
      });
      expect(m.is360Video, isTrue);
      expect(m.projectionType, Video360Projection.equirectangular);
      expect(m.stereoMode, Video360StereoMode.mono);
      expect(m.use360Player, isTrue);
    });

    test('round-trip is stable', () {
      const original = Video360Metadata(
        is360Video: true,
        projectionType: Video360Projection.equirectangular,
        stereoMode: Video360StereoMode.topBottom,
      );
      final back = Video360Metadata.fromPost(original.toFirestore());
      expect(back.is360Video, original.is360Video);
      expect(back.projectionType, original.projectionType);
      expect(back.stereoMode, original.stereoMode);
    });
  });

  group('sanitize', () {
    test('non-360 collapses to flat', () {
      final m = Video360Metadata.sanitize(
        is360Video: false,
        projectionType: 'equirectangular',
        stereoMode: 'mono',
      );
      expect(m.is360Video, isFalse);
      expect(m.use360Player, isFalse);
    });
    test('360 with non-equirectangular downgrades to flat', () {
      final m = Video360Metadata.sanitize(
        is360Video: true,
        projectionType: 'cubemap',
        stereoMode: 'mono',
      );
      expect(m.use360Player, isFalse);
    });
    test('valid 360 stays 360', () {
      final m = Video360Metadata.sanitize(
        is360Video: true,
        projectionType: 'equirectangular',
        stereoMode: 'mono',
      );
      expect(m.use360Player, isTrue);
    });
  });

  group('forVrPlayback legacy compatibility', () {
    test(
      'legacy isVR post without is360Video is treated as equirectangular',
      () {
        final m = Video360Metadata.forVrPlayback({'isVR': true});
        expect(m.use360Player, isTrue);
        expect(m.projectionType, Video360Projection.equirectangular);
      },
    );
    test('plain flat post stays flat', () {
      final m = Video360Metadata.forVrPlayback({'isVR': false});
      expect(m.use360Player, isFalse);
    });
  });
}
