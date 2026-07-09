import '../models/live_stream_model.dart';

/// How the live-stream viewer screen should render host video.
enum LiveStreamViewerVideoMode {
  /// URL-based interactive sphere ([Live360View]).
  interactive360,

  /// Standard Agora remote video (flat ERP when stream is 360-tagged but has no URL).
  flatAgora,

  /// Host video not available yet — show connecting placeholder only.
  waitingForHost,
}

/// Pure routing for viewer playback — no widgets, safe to unit test.
class LiveStreamViewerPlayback {
  LiveStreamViewerPlayback._();

  static LiveStreamViewerVideoMode videoMode({
    required LiveStreamModel doc,
    required bool engineReady,
    required bool hostVideoAvailable,
    required int remoteUid,
  }) {
    if (doc.canRenderInteractive360) {
      return LiveStreamViewerVideoMode.interactive360;
    }
    if (!engineReady || !hostVideoAvailable || remoteUid == 0) {
      return LiveStreamViewerVideoMode.waitingForHost;
    }
    return LiveStreamViewerVideoMode.flatAgora;
  }

  /// 360 metadata is present but [LiveStreamModel.canRenderInteractive360] is false.
  static bool showInteractiveUnavailableNotice(LiveStreamModel doc) =>
      doc.use360Player && !doc.canRenderInteractive360;
}
