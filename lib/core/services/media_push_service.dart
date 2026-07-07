import 'package:agora_rtc_engine/agora_rtc_engine.dart';

/// Bridges a live Agora stream to a CDN via **Media Push**, producing an HLS URL
/// so the URL-based interactive 360 viewer ([Live360View]) has something to play.
///
/// GATED OFF ([enabled] == false) for this pass: it is implemented and unit-tested
/// but **not invoked at go-live** — no real stream is pushed to a CDN (avoids CDN
/// cost and avoids going live). To activate: provision CDN ingest, set [enabled]
/// = true, and pass the ingest/playback URLs.
///
/// SCOPE NOTE: Media Push / CDN is OUTSIDE the capture-side POC contract
/// (transport + backend distribution + CDN). This is a client-directed add-on —
/// see `360 Viewer Integration — Scope, Availability & Reuse.md`.
class MediaPushService {
  const MediaPushService();

  /// Master switch. Keep false until CDN ingest is provisioned and a live push is
  /// actually intended. While false, all methods are safe no-ops.
  static const bool enabled = false;

  /// Start pushing the joined Agora channel to [rtmpIngestUrl] (single host, no
  /// transcoding). Returns [hlsPlaybackUrl] for the viewer, or null when disabled.
  Future<String?> start({
    required RtcEngine engine,
    required String rtmpIngestUrl,
    required String hlsPlaybackUrl,
  }) async {
    if (!enabled) return null;
    await engine.startRtmpStreamWithoutTranscoding(rtmpIngestUrl);
    return hlsPlaybackUrl;
  }

  /// Stop the Media Push for [rtmpIngestUrl]. No-op when disabled.
  Future<void> stop({
    required RtcEngine engine,
    required String rtmpIngestUrl,
  }) async {
    if (!enabled) return;
    await engine.stopRtmpStream(rtmpIngestUrl);
  }

  /// Pure helper: HLS playback URL for a Cloudflare Stream (Live Input) video id.
  /// Matches the URL shape `StreamPlaybackUrls` expands.
  static String cloudflareHlsUrl(String videoId) =>
      'https://videodelivery.net/${videoId.trim()}/manifest/video.m3u8';
}
