import 'dart:async';
import 'dart:math' as math;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/device_motion_tracker.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// How the gyro viewport maps onto the incoming Agora video.
enum LiveGyroProjectionMode {
  /// Subtle parallax pan for standard flat live camera feeds.
  flat,

  /// Equirectangular 360° — host publishes a 2:1 spherical frame via Agora.
  equirectangular,
}

/// Agora remote video with gyroscope look-around and touch pan.
class LiveStreamGyroVideoView extends StatefulWidget {
  const LiveStreamGyroVideoView({
    super.key,
    required this.rtcEngine,
    required this.remoteUid,
    required this.channelId,
    this.projectionMode = LiveGyroProjectionMode.flat,
    this.gyroEnabled = true,
    this.motionActive = true,
    this.touchEnabled = true,
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
  final bool touchEnabled;
  final bool showGyroToggle;
  final double gyroToggleTopInset;
  final ValueChanged<bool>? onGyroEnabledChanged;

  @override
  State<LiveStreamGyroVideoView> createState() => _LiveStreamGyroVideoViewState();
}

class _LiveStreamGyroVideoViewState extends State<LiveStreamGyroVideoView>
    with WidgetsBindingObserver {
  final _motion = DeviceMotionTracker(maxPitchRad: math.pi / 2);
  late bool _gyroEnabled;
  VideoViewController? _videoController;
  int _boundRemoteUid = 0;
  String _boundChannelId = '';

  double _touchYaw = 0;
  double _touchPitch = 0;
  double _dragYaw = 0;
  double _dragPitch = 0;
  bool _isDragging = false;

  bool get _is360 => widget.projectionMode == LiveGyroProjectionMode.equirectangular;

  @override
  void initState() {
    super.initState();
    _gyroEnabled = widget.gyroEnabled;
    WidgetsBinding.instance.addObserver(this);
    _ensureVideoController();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant LiveStreamGyroVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gyroEnabled != widget.gyroEnabled) {
      _gyroEnabled = widget.gyroEnabled;
    }
    if (oldWidget.remoteUid != widget.remoteUid ||
        oldWidget.channelId != widget.channelId ||
        oldWidget.projectionMode != widget.projectionMode) {
      _disposeVideoController();
      _ensureVideoController();
    }
    if (oldWidget.motionActive != widget.motionActive ||
        oldWidget.gyroEnabled != widget.gyroEnabled) {
      _syncMotion();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncMotion();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _motion.stop();
    }
  }

  void _syncMotion() {
    if (widget.motionActive && _gyroEnabled && !kIsWeb) {
      unawaited(_motion.start().then((_) {
        if (!mounted) return;
        if (!_motion.isAvailable.value && _gyroEnabled) {
          setState(() => _gyroEnabled = false);
        }
      }));
    } else {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    _disposeVideoController();
    super.dispose();
  }

  void _ensureVideoController() {
    if (widget.remoteUid == 0 || widget.channelId.isEmpty) return;
    if (_videoController != null &&
        _boundRemoteUid == widget.remoteUid &&
        _boundChannelId == widget.channelId) {
      return;
    }
    _videoController = VideoViewController.remote(
      rtcEngine: widget.rtcEngine,
      canvas: VideoCanvas(
        uid: widget.remoteUid,
        // Fit preserves the full 2:1 equirectangular frame; hidden crops to portrait.
        renderMode: _is360
            ? RenderModeType.renderModeFit
            : RenderModeType.renderModeHidden,
      ),
      connection: RtcConnection(channelId: widget.channelId),
      useFlutterTexture: !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android),
    );
    _boundRemoteUid = widget.remoteUid;
    _boundChannelId = widget.channelId;
  }

  Future<void> _disposeVideoController() async {
    final controller = _videoController;
    _videoController = null;
    _boundRemoteUid = 0;
    _boundChannelId = '';
    if (controller != null) {
      await controller.dispose();
    }
  }

  void _toggleGyro() {
    setState(() {
      _gyroEnabled = !_gyroEnabled;
      if (!_gyroEnabled) {
        _motion.reset();
        _touchYaw = 0;
        _touchPitch = 0;
      }
    });
    _syncMotion();
    widget.onGyroEnabledChanged?.call(_gyroEnabled);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    if (controller == null) {
      return const ColoredBox(color: Colors.black);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onPanStart: widget.touchEnabled
                  ? (_) {
                      setState(() => _isDragging = true);
                    }
                  : null,
              onPanUpdate: widget.touchEnabled
                  ? (details) {
                      final hSens = _is360 ? 0.012 : 0.002;
                      final vSens = _is360 ? 0.012 : 0.002;
                      setState(() {
                        _dragYaw -= details.delta.dx * hSens;
                        _dragPitch += details.delta.dy * vSens;
                        _clampTouchAngles();
                      });
                    }
                  : null,
              onPanEnd: widget.touchEnabled
                  ? (_) {
                      setState(() {
                        _isDragging = false;
                        _touchYaw += _dragYaw;
                        _touchPitch += _dragPitch;
                        _dragYaw = 0;
                        _dragPitch = 0;
                        _clampTouchAngles();
                      });
                    }
                  : null,
              child: ClipRect(
                child: ValueListenableBuilder<DeviceMotionSample>(
                  valueListenable: _motion.sample,
                  builder: (context, motion, _) {
                    final gyroYaw =
                        _gyroEnabled && widget.motionActive ? motion.yaw : 0.0;
                    final gyroPitch =
                        _gyroEnabled && widget.motionActive ? motion.pitch : 0.0;
                    final yaw = gyroYaw + _touchYaw + _dragYaw;
                    final pitch = gyroPitch + _touchPitch + _dragPitch;

                    return _buildViewport(
                      width: width,
                      height: height,
                      yaw: yaw,
                      pitch: pitch,
                      controller: controller,
                    );
                  },
                ),
              ),
            ),
            if (widget.showGyroToggle) _buildGyroToggle(),
          ],
        );
      },
    );
  }

  void _clampTouchAngles() {
    if (_is360) {
      // Full-sphere look-around — yaw can spin freely; pitch capped to ±90°.
      final totalPitch = _touchPitch + _dragPitch;
      const maxPitch = math.pi / 2;
      if (totalPitch.abs() > maxPitch) {
        final excess = totalPitch.sign * (totalPitch.abs() - maxPitch);
        if (_isDragging) {
          _dragPitch -= excess;
        } else {
          _touchPitch -= excess;
        }
      }
      return;
    }

    const maxYaw = math.pi / 6;
    const maxPitch = math.pi / 10;
    final totalYaw = _touchYaw + _dragYaw;
    final totalPitch = _touchPitch + _dragPitch;
    if (totalYaw.abs() > maxYaw) {
      final excess = totalYaw.sign * (totalYaw.abs() - maxYaw);
      if (_isDragging) {
        _dragYaw -= excess;
      } else {
        _touchYaw -= excess;
      }
    }
    if (totalPitch.abs() > maxPitch) {
      final excess = totalPitch.sign * (totalPitch.abs() - maxPitch);
      if (_isDragging) {
        _dragPitch -= excess;
      } else {
        _touchPitch -= excess;
      }
    }
  }

  Widget _buildViewport({
    required double width,
    required double height,
    required double yaw,
    required double pitch,
    required VideoViewController controller,
  }) {
    if (_is360) {
      return _buildEquirectangularViewport(
        viewportWidth: width,
        viewportHeight: height,
        yaw: yaw,
        pitch: pitch,
        controller: controller,
      );
    }

    // Flat live — subtle immersive parallax.
    const scale = 1.28;
    final videoW = width * scale;
    final videoH = height * scale;
    final panX = (yaw / (math.pi / 3)) * (videoW - width) * 0.5;
    final panY = (pitch / (math.pi / 4)) * (videoH - height) * 0.5;

    return OverflowBox(
      maxWidth: videoW,
      maxHeight: videoH,
      alignment: Alignment.center,
      child: Transform.translate(
        offset: Offset(-panX, -panY),
        child: SizedBox(
          width: videoW,
          height: videoH,
          child: AgoraVideoView(controller: controller),
        ),
      ),
    );
  }

  /// Pans a viewport across the full unstitched 2:1 equirectangular Agora frame.
  Widget _buildEquirectangularViewport({
    required double viewportWidth,
    required double viewportHeight,
    required double yaw,
    required double pitch,
    required VideoViewController controller,
  }) {
    // 2:1 canvas — width spans 360°, height spans 180°.
    final canvasHeight = math.max(viewportHeight * 2, viewportWidth);
    final canvasWidth = canvasHeight * 2;

    final maxPanX = math.max(1.0, canvasWidth - viewportWidth);
    final maxPanY = math.max(1.0, canvasHeight - viewportHeight);

    // Continuous yaw from gyro; wrap horizontally.
    var panX = (yaw / (2 * math.pi)) * maxPanX;
    panX = panX % maxPanX;
    if (panX < 0) panX += maxPanX;

    // Pitch: -π/2 (down) … +π/2 (up) mapped to vertical pan.
    final pitchNorm = (pitch / math.pi + 0.5).clamp(0.0, 1.0);
    final panY = pitchNorm * maxPanY;

    return ClipRect(
      child: OverflowBox(
        maxWidth: canvasWidth,
        maxHeight: canvasHeight,
        alignment: Alignment.topLeft,
        child: Transform.translate(
          offset: Offset(-panX, -panY),
          child: SizedBox(
            width: canvasWidth,
            height: canvasHeight,
            child: AgoraVideoView(controller: controller),
          ),
        ),
      ),
    );
  }

  Widget _buildGyroToggle() {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + AppSpacing.sm + widget.gyroToggleTopInset,
      right: AppSpacing.md,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: _motion.isAvailable.value ? _toggleGyro : null,
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
                  _gyroEnabled ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                  color: _gyroEnabled ? const Color(0xFF00E5A0) : Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  !_motion.isAvailable.value
                      ? 'Gyro N/A'
                      : _is360
                          ? (_gyroEnabled ? '360° Gyro' : '360° off')
                          : (_gyroEnabled ? 'Gyro on' : 'Gyro off'),
                  style: AppTypography.feedReelHandle.copyWith(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
