import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/models/live_stream_model.dart';
import 'package:vyooo/core/models/video_360_metadata.dart';
import 'package:vyooo/core/utils/live_stream_viewer_playback.dart';

LiveStreamModel _stream({
  Video360Metadata video360 = Video360Metadata.flat,
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
    hlsUrl: hlsUrl,
  );
}

void main() {
  const meta360 = Video360Metadata(
    is360Video: true,
    projectionType: Video360Projection.equirectangular,
    stereoMode: Video360StereoMode.mono,
  );

  const validHls =
      'https://customer-abc.cloudflarestream.com/vid123/manifest/video.m3u8';

  group('hasPlayableHlsUrl / canRenderInteractive360', () {
    test('360 stream with valid playable URL', () {
      final s = _stream(video360: meta360, hlsUrl: validHls);
      expect(s.hasPlayableHlsUrl, isTrue);
      expect(s.canRenderInteractive360, isTrue);
    });

    test('360 stream with empty hlsUrl', () {
      final s = _stream(video360: meta360);
      expect(s.hasPlayableHlsUrl, isFalse);
      expect(s.canRenderInteractive360, isFalse);
    });

    test('360 stream with whitespace-only hlsUrl', () {
      final s = _stream(video360: meta360, hlsUrl: '   ');
      expect(s.hasPlayableHlsUrl, isFalse);
      expect(s.canRenderInteractive360, isFalse);
    });

    test('360 stream with invalid hlsUrl', () {
      final s = _stream(video360: meta360, hlsUrl: 'not-a-url');
      expect(s.hasPlayableHlsUrl, isFalse);
      expect(s.canRenderInteractive360, isFalse);
    });

    test('360 metadata without playback URL', () {
      final s = _stream(video360: meta360);
      expect(s.use360Player, isTrue);
      expect(s.canRenderInteractive360, isFalse);
    });

    test('normal non-360 Agora stream with URL does not route interactive', () {
      final s = _stream(hlsUrl: validHls);
      expect(s.use360Player, isFalse);
      expect(s.canRenderInteractive360, isFalse);
    });

    test('partial metadata: is360 without equirectangular projection', () {
      final s = _stream(
        video360: const Video360Metadata(
          is360Video: true,
          projectionType: Video360Projection.flat,
        ),
        hlsUrl: validHls,
      );
      expect(s.canRenderInteractive360, isFalse);
    });
  });

  group('LiveStreamViewerPlayback.videoMode', () {
    test(
      'interactive when 360 + valid URL even before Agora remote is ready',
      () {
        final doc = _stream(video360: meta360, hlsUrl: validHls);
        expect(
          LiveStreamViewerPlayback.videoMode(
            doc: doc,
            engineReady: false,
            hostVideoAvailable: false,
            remoteUid: 0,
          ),
          LiveStreamViewerVideoMode.interactive360,
        );
      },
    );

    test('waiting when flat stream and host not visible', () {
      final doc = _stream();
      expect(
        LiveStreamViewerPlayback.videoMode(
          doc: doc,
          engineReady: true,
          hostVideoAvailable: false,
          remoteUid: 0,
        ),
        LiveStreamViewerVideoMode.waitingForHost,
      );
    });

    test('flat Agora for 360-tagged stream without playable URL', () {
      final doc = _stream(video360: meta360);
      expect(
        LiveStreamViewerPlayback.videoMode(
          doc: doc,
          engineReady: true,
          hostVideoAvailable: true,
          remoteUid: 42,
        ),
        LiveStreamViewerVideoMode.flatAgora,
      );
    });

    test('normal non-360 uses flat Agora when host is visible', () {
      final doc = _stream();
      expect(
        LiveStreamViewerPlayback.videoMode(
          doc: doc,
          engineReady: true,
          hostVideoAvailable: true,
          remoteUid: 7,
        ),
        LiveStreamViewerVideoMode.flatAgora,
      );
    });

    test('fallback from interactive to flat when URL removed at runtime', () {
      var doc = _stream(video360: meta360, hlsUrl: validHls);
      expect(
        LiveStreamViewerPlayback.videoMode(
          doc: doc,
          engineReady: true,
          hostVideoAvailable: true,
          remoteUid: 3,
        ),
        LiveStreamViewerVideoMode.interactive360,
      );

      doc = doc.copyWith(hlsUrl: '');
      expect(doc.canRenderInteractive360, isFalse);
      expect(
        LiveStreamViewerPlayback.videoMode(
          doc: doc,
          engineReady: true,
          hostVideoAvailable: true,
          remoteUid: 3,
        ),
        LiveStreamViewerVideoMode.flatAgora,
      );
    });

    test('playback URL added after viewer screen opens', () {
      var doc = _stream(video360: meta360);
      expect(
        LiveStreamViewerPlayback.videoMode(
          doc: doc,
          engineReady: true,
          hostVideoAvailable: true,
          remoteUid: 9,
        ),
        LiveStreamViewerVideoMode.flatAgora,
      );

      doc = doc.copyWith(hlsUrl: validHls);
      expect(
        LiveStreamViewerPlayback.videoMode(
          doc: doc,
          engineReady: true,
          hostVideoAvailable: true,
          remoteUid: 9,
        ),
        LiveStreamViewerVideoMode.interactive360,
      );
    });
  });

  group('showInteractiveUnavailableNotice', () {
    test('true for 360 metadata without playable URL', () {
      final doc = _stream(video360: meta360);
      expect(
        LiveStreamViewerPlayback.showInteractiveUnavailableNotice(doc),
        isTrue,
      );
    });

    test('false when interactive URL is available', () {
      final doc = _stream(video360: meta360, hlsUrl: validHls);
      expect(
        LiveStreamViewerPlayback.showInteractiveUnavailableNotice(doc),
        isFalse,
      );
    });

    test('false for normal flat stream', () {
      final doc = _stream();
      expect(
        LiveStreamViewerPlayback.showInteractiveUnavailableNotice(doc),
        isFalse,
      );
    });
  });
}
