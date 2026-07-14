import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../models/live_stream_model.dart';
import '../utils/live_360_video.dart';
import 'live_stream_gyro_video_view.dart';

/// Shared live remote-video surface for broadcast feed and standalone viewer.
class LiveStreamVideoSurface extends StatelessWidget {
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

  LiveGyroProjectionMode get _projectionMode => resolveLiveGyroProjectionMode(
        stream: stream,
        remoteVideoWidth: remoteVideoWidth,
        remoteVideoHeight: remoteVideoHeight,
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        LiveStreamGyroVideoView(
          rtcEngine: rtcEngine,
          remoteUid: remoteUid,
          channelId: stream.agoraChannelName,
          projectionMode: _projectionMode,
          gyroEnabled: gyroEnabled,
          motionActive: motionActive,
          showGyroToggle: showGyroToggle,
          gyroToggleTopInset: gyroToggleTopInset,
          onGyroEnabledChanged: onGyroEnabledChanged,
        ),
        ?scrubOverlay,
      ],
    );
  }
}
