import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/models/live_stream_model.dart';
import 'package:vyooo/core/models/video_360_metadata.dart';

LiveStreamModel _base({
  Video360Metadata video360 = Video360Metadata.flat,
  bool isVR = false,
  String? hlsUrl,
}) {
  return LiveStreamModel(
    id: 's1',
    hostId: 'h1',
    hostUsername: 'host',
    title: 'T',
    status: LiveStreamStatus.live,
    agoraChannelName: 's1',
    createdAt: Timestamp.now(),
    video360: video360,
    isVR: isVR,
    hlsUrl: hlsUrl,
  );
}

void main() {
  const meta360 = Video360Metadata(
    is360Video: true,
    projectionType: Video360Projection.equirectangular,
    stereoMode: Video360StereoMode.mono,
  );

  group('serialization of 360 fields', () {
    test('toJson writes reference keys for a 360 stream', () {
      final json = _base(
        video360: meta360,
        isVR: true,
        hlsUrl: 'https://x/y.m3u8',
      ).toJson();
      expect(json['is360Video'], true);
      expect(json['projectionType'], 'equirectangular');
      expect(json['stereoMode'], 'mono');
      expect(json['isVR'], true);
      expect(json['hlsUrl'], 'https://x/y.m3u8');
    });

    test('flat stream omits hlsUrl and marks is360Video false', () {
      final json = _base().toJson();
      expect(json['is360Video'], false);
      expect(json.containsKey('hlsUrl'), isFalse);
    });

    test('fromJson round-trips 360 + hlsUrl', () {
      final json = _base(
        video360: meta360,
        isVR: true,
        hlsUrl: 'https://x/y.m3u8',
      ).toJson();
      json['createdAt'] = Timestamp.now();
      final back = LiveStreamModel.fromJson(json);
      expect(back.use360Player, isTrue);
      expect(back.isVR, isTrue);
      expect(back.hlsUrl, 'https://x/y.m3u8');
      expect(back.video360.projectionType, Video360Projection.equirectangular);
    });

    test('blank/whitespace hlsUrl reads back as null', () {
      final json = _base(video360: meta360, hlsUrl: '   ').toJson();
      // toJson keeps the key only when non-null; simulate a doc that stored blank.
      json['hlsUrl'] = '   ';
      json['createdAt'] = Timestamp.now();
      final back = LiveStreamModel.fromJson(json);
      expect(back.hlsUrl, isNull);
    });
  });

  group('viewer render decision (canRenderInteractive360)', () {
    test('360 + hlsUrl → interactive', () {
      final s = _base(video360: meta360, hlsUrl: 'https://x/y.m3u8');
      expect(s.use360Player, isTrue);
      expect(s.canRenderInteractive360, isTrue);
    });

    test('360 but NO url → NOT interactive (flat fallback)', () {
      final s = _base(video360: meta360);
      expect(s.use360Player, isTrue);
      expect(s.canRenderInteractive360, isFalse);
    });

    test('non-360 with a url → NOT interactive', () {
      final s = _base(hlsUrl: 'https://x/y.m3u8');
      expect(s.canRenderInteractive360, isFalse);
    });

    test('blank url → NOT interactive', () {
      final s = _base(video360: meta360, hlsUrl: '   ');
      expect(s.canRenderInteractive360, isFalse);
    });

    test('invalid url → NOT interactive', () {
      final s = _base(video360: meta360, hlsUrl: 'not-a-url');
      expect(s.hasPlayableHlsUrl, isFalse);
      expect(s.canRenderInteractive360, isFalse);
    });

    test('valid cloudflare manifest → interactive', () {
      final s = _base(
        video360: meta360,
        hlsUrl:
            'https://customer-abc.cloudflarestream.com/vid123/manifest/video.m3u8',
      );
      expect(s.hasPlayableHlsUrl, isTrue);
      expect(s.canRenderInteractive360, isTrue);
    });
  });
}
