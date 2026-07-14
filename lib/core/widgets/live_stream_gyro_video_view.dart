import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'live_360_panorama_view.dart';

/// How the incoming Agora video is scaled on the viewer.
enum LiveGyroProjectionMode {
  /// Standard flat live camera — fill the screen.
  flat,

  /// Equirectangular 360° — host flagged [LiveStreamModel.is360Live].
  equirectangular,
}

/// Agora remote video for live viewers.
///
/// Flat streams use a full-screen [AgoraVideoView]. 360° streams render on an
/// inverted sphere with gyro look-around via [Live360PanoramaView].
class LiveStreamGyroVideoView extends StatefulWidget {
  const LiveStreamGyroVideoView({
    super.key,
    required this.rtcEngine,
    required this.remoteUid,
    required this.channelId,
    this.projectionMode = LiveGyroProjectionMode.flat,
    this.gyroEnabled = true,
    this.motionActive = true,
    this.showGyroToggle = true,
    this.gyroToggleTopInset = 0,
    this.onGyroEnabledChanged,
  });

  final RtcEngine rtcEngine;
  final int remoteUid;
  final String channelId;
  final LiveGyroProjectionMode projectionMode;
  final bool gyroEnabled;
  final bool motionActive;
  final bool showGyroToggle;
  final double gyroToggleTopInset;
  final ValueChanged<bool>? onGyroEnabledChanged;

  @override
  State<LiveStreamGyroVideoView> createState() => _LiveStreamGyroVideoViewState();
}

class _LiveStreamGyroVideoViewState extends State<LiveStreamGyroVideoView> {
  VideoViewController? _videoController;
  final Live360PanoramaViewController _panoramaController =
      Live360PanoramaViewController();
  int _boundRemoteUid = 0;
  String _boundChannelId = '';
  LiveGyroProjectionMode? _boundProjectionMode;

  bool get _is360 =>
      widget.projectionMode == LiveGyroProjectionMode.equirectangular;

  bool get _gyroActive => widget.gyroEnabled && widget.motionActive;

  @override
  void initState() {
    super.initState();
    _syncVideoController();
  }

  @override
  void didUpdateWidget(covariant LiveStreamGyroVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was360 =
        oldWidget.projectionMode == LiveGyroProjectionMode.equirectangular;
    if (was360 != _is360) {
      if (_is360) {
        final old = _videoController;
        _videoController = null;
        _boundRemoteUid = 0;
        _boundChannelId = '';
        _boundProjectionMode = null;
        unawaited(old?.dispose());
      } else {
        unawaited(_replaceVideoController());
      }
      return;
    }
    if (!_is360 &&
        (oldWidget.remoteUid != widget.remoteUid ||
            oldWidget.channelId != widget.channelId ||
            oldWidget.projectionMode != widget.projectionMode)) {
      unawaited(_replaceVideoController());
    }
  }

  @override
  void dispose() {
    final controller = _videoController;
    _videoController = null;
    unawaited(controller?.dispose());
    super.dispose();
  }

  void _syncVideoController() {
    if (_is360) return;
    if (widget.remoteUid == 0 || widget.channelId.isEmpty) return;
    if (_videoController != null &&
        _boundRemoteUid == widget.remoteUid &&
        _boundChannelId == widget.channelId &&
        _boundProjectionMode == widget.projectionMode) {
      return;
    }
    _videoController = VideoViewController.remote(
      rtcEngine: widget.rtcEngine,
      canvas: VideoCanvas(
        uid: widget.remoteUid,
        renderMode: RenderModeType.renderModeHidden,
      ),
      connection: RtcConnection(channelId: widget.channelId),
    );
    _boundRemoteUid = widget.remoteUid;
    _boundChannelId = widget.channelId;
    _boundProjectionMode = widget.projectionMode;
  }

  Future<void> _replaceVideoController() async {
    final old = _videoController;
    _videoController = null;
    _boundRemoteUid = 0;
    _boundChannelId = '';
    _boundProjectionMode = null;
    await old?.dispose();
    if (!mounted) return;
    _syncVideoController();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_is360) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Live360PanoramaView(
            rtcEngine: widget.rtcEngine,
            remoteUid: widget.remoteUid,
            channelId: widget.channelId,
            controller: _panoramaController,
            gyroEnabled: _gyroActive,
            touchEnabled: true,
          ),
          if (widget.showGyroToggle) _buildTopChrome(),
        ],
      );
    }

    _syncVideoController();
    final controller = _videoController;
    if (controller == null) {
      return const ColoredBox(color: Colors.black);
    }

    final viewKey = ValueKey(
      'live_remote_${widget.channelId}_${widget.remoteUid}_flat',
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        SizedBox.expand(
          child: AgoraVideoView(
            key: viewKey,
            controller: controller,
          ),
        ),
        if (widget.showGyroToggle) _buildTopChrome(isFlat: true),
      ],
    );
  }

  Widget _buildTopChrome({bool isFlat = false}) {
    final top = MediaQuery.paddingOf(context).top +
        AppSpacing.sm +
        widget.gyroToggleTopInset;

    return Positioned(
      top: top,
      right: AppSpacing.md,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFlat && _gyroActive) ...[
            _buildRecalibrateButton(),
            const SizedBox(width: AppSpacing.xs),
          ],
          _buildModeBadge(isFlat: isFlat),
        ],
      ),
    );
  }

  Widget _buildRecalibrateButton() {
    return Tooltip(
      message: 'Recenter view',
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: _handleRecalibrateGyro,
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.xs),
            child: Icon(
              Icons.explore_rounded,
              color: Color(0xFF00E5A0),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  void _handleRecalibrateGyro() {
    if (!_panoramaController.isAttached) return;
    HapticFeedback.lightImpact();
    _panoramaController.recalibrateGyro();
  }

  Widget _buildModeBadge({bool isFlat = false}) {
    final label = _is360
        ? (_gyroActive ? '360° Gyro' : '360° Live')
        : 'Live';

    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _is360 ? Icons.sensors_rounded : Icons.videocam_rounded,
              color: _is360
                  ? const Color(0xFF00E5A0)
                  : Colors.white.withValues(alpha: 0.85),
              size: 18,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.feedReelHandle.copyWith(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
