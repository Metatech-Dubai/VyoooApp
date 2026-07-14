import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../models/live_stream_model.dart';
import '../utils/live_360_meta_log.dart';
import '../utils/live_360_video.dart';
import 'live_stream_gyro_video_view.dart';

/// Shared live remote-video surface for broadcast feed and standalone viewer.
class LiveStreamVideoSurface extends StatefulWidget {
  const LiveStreamVideoSurface({
    super.key,
    required this.rtcEngine,
    required this.remoteUid,
    required this.stream,
    this.motionActive = true,
    this.gyroEnabled = true,
    this.showGyroToggle = true,
    this.gyroToggleTopInset = 0,
    this.remoteVideoWidth,
    this.remoteVideoHeight,
    this.scrubOverlay,
    this.onGyroEnabledChanged,
  });

  final RtcEngine rtcEngine;
  final int remoteUid;
  final LiveStreamModel stream;
  final bool motionActive;
  final bool gyroEnabled;
  final bool showGyroToggle;
  final double gyroToggleTopInset;
  final int? remoteVideoWidth;
  final int? remoteVideoHeight;
  final Widget? scrubOverlay;
  final ValueChanged<bool>? onGyroEnabledChanged;

  @override
  State<LiveStreamVideoSurface> createState() => _LiveStreamVideoSurfaceState();
}

class _LiveStreamVideoSurfaceState extends State<LiveStreamVideoSurface> {
  LiveGyroProjectionMode get _projectionMode => resolveLiveGyroProjectionMode(
        stream: widget.stream,
        remoteVideoWidth: widget.remoteVideoWidth,
        remoteVideoHeight: widget.remoteVideoHeight,
      );

  @override
  void initState() {
    super.initState();
    _logMeta('video_surface_init');
  }

  @override
  void didUpdateWidget(covariant LiveStreamVideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream.id != widget.stream.id ||
        oldWidget.stream.is360Live != widget.stream.is360Live ||
        oldWidget.stream.projectionType != widget.stream.projectionType ||
        oldWidget.remoteVideoWidth != widget.remoteVideoWidth ||
        oldWidget.remoteVideoHeight != widget.remoteVideoHeight ||
        oldWidget.motionActive != widget.motionActive ||
        oldWidget.gyroEnabled != widget.gyroEnabled) {
      _logMeta('video_surface_update');
    }
  }

  void _logMeta(String source) {
    Live360MetaLog.log(
      source: source,
      stream: widget.stream,
      remoteVideoWidth: widget.remoteVideoWidth,
      remoteVideoHeight: widget.remoteVideoHeight,
      motionActive: widget.motionActive,
      gyroEnabled: widget.gyroEnabled,
      resolvedMode: _projectionMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        LiveStreamGyroVideoView(
          key: ValueKey(
            'live_surface_${widget.stream.id}_${_projectionMode.name}',
          ),
          rtcEngine: widget.rtcEngine,
          remoteUid: widget.remoteUid,
          channelId: widget.stream.agoraChannelName,
          projectionMode: _projectionMode,
          gyroEnabled: widget.gyroEnabled,
          motionActive: widget.motionActive,
          showGyroToggle: widget.showGyroToggle,
          gyroToggleTopInset: widget.gyroToggleTopInset,
          onGyroEnabledChanged: widget.onGyroEnabledChanged,
        ),
        ?widget.scrubOverlay,
      ],
    );
  }
}
