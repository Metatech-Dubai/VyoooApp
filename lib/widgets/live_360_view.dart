import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_360/video_360.dart';
import 'package:video_player/video_player.dart';

import '../core/utils/stream_playback_urls.dart';

/// Interactive 360 player for a **live** stream URL (HLS/MP4), reusing the 360 VOD
/// team's [Video360View] renderer (sphere + gyroscope + touch, built in). Falls
/// back to a flat [VideoPlayer] when native 360 is unavailable or fails.
///
/// This is a slim, live-oriented adaptation of their `Vyooo360VideoPlayer`
/// (feed-specific glue — offline cache, feed audio, like overlays — omitted).
/// It plays a URL because that is the only input [Video360View] accepts; the URL
/// is produced upstream by exposing the live stream as HLS (Agora Media Push).
class Live360View extends StatefulWidget {
  const Live360View({
    super.key,
    required this.streamUrl,
    this.autoPlay = true,
  });

  /// The live stream URL (Cloudflare/CDN HLS or MP4). May be a manifest URL that
  /// [StreamPlaybackUrls] expands into MP4/HLS candidates.
  final String streamUrl;
  final bool autoPlay;

  /// Whether native interactive 360 is possible on this platform.
  static bool get supportsNative360 =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  State<Live360View> createState() => _Live360ViewState();
}

class _Live360ViewState extends State<Live360View> {
  Video360Controller? _native;
  VideoPlayerController? _flat;

  late List<String> _candidates;
  int _urlIndex = 0;
  bool _useFlatFallback = false;
  bool _flatReady = false;
  bool _error = false;

  String? get _currentUrl =>
      (_urlIndex >= 0 && _urlIndex < _candidates.length) ? _candidates[_urlIndex] : null;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant Live360View oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _disposeFlat();
      _native = null;
      _resolve();
    }
  }

  void _resolve() {
    // MP4-first ordering (native 360 handles progressive MP4 more reliably than HLS).
    _candidates = StreamPlaybackUrls.candidatesPreferMp4(widget.streamUrl);
    _urlIndex = 0;
    _useFlatFallback = !Live360View.supportsNative360;
    _error = _candidates.isEmpty;
    if (_useFlatFallback && !_error) _initFlat();
    if (mounted) setState(() {});
  }

  Future<void> _initFlat() async {
    final url = _currentUrl;
    if (url == null) {
      setState(() => _error = true);
      return;
    }
    _disposeFlat();
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _flat = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      if (widget.autoPlay) await c.play();
      if (mounted) setState(() => _flatReady = true);
    } catch (_) {
      _advanceOrFail();
    }
  }

  /// Try the next candidate URL; if none remain, show the error state.
  void _advanceOrFail() {
    if (_urlIndex + 1 < _candidates.length) {
      _urlIndex++;
      if (_useFlatFallback) {
        _initFlat();
      } else {
        setState(() {}); // rebuild Video360View with next url
      }
    } else if (!_useFlatFallback) {
      // Native 360 exhausted its candidates → drop to flat playback.
      _useFlatFallback = true;
      _urlIndex = 0;
      _initFlat();
    } else {
      if (mounted) setState(() => _error = true);
    }
  }

  void _disposeFlat() {
    _flat?.dispose();
    _flat = null;
    _flatReady = false;
  }

  @override
  void dispose() {
    _disposeFlat();
    unawaited(_native?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error || _currentUrl == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text('360 playback unavailable — showing flat view',
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    if (_useFlatFallback) {
      if (!_flatReady || _flat == null) {
        return const ColoredBox(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      }
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _flat!.value.size.width,
          height: _flat!.value.size.height,
          child: VideoPlayer(_flat!),
        ),
      );
    }

    // Interactive native 360 (gyro + touch handled inside the package).
    return Video360View(
      key: ValueKey('live360-${_currentUrl!}-$_urlIndex'),
      url: _currentUrl!,
      isRepeat: true,
      useAndroidViewSurface: true,
      onVideo360ViewCreated: (c) {
        _native = c;
        if (widget.autoPlay) c.play();
      },
      onPlayInfo: (_) {},
    );
  }
}
