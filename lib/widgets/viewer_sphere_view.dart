import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/services/gyro_look_controller.dart';

/// Fullscreen head-tracked 360 sphere for the VITURE XR viewer.
///
/// Parallel to [Live360View], but instead of playing a URL it renders the **live Agora ERP stream**
/// on a native GL sphere ([ViewerSphereView] platform view, type `vyooo/viewer_sphere`) whose camera
/// is driven by the VITURE head pose natively. This widget wires the two Dart-side inputs the native
/// sphere needs:
///
///   1. **Frames** — it registers an Agora [VideoFrameObserver] on the shared [RtcEngine] and forwards
///      each remote ERP frame (I420) to the sphere via the `vyooo/viewer_sphere` method channel,
///      coalescing to the latest frame (drop-stale) so the channel is never flooded.
///   2. **Fallback orientation** — an optional gyro look-around (via [GyroLookController]) for testing
///      without glasses, pushed as a `setViewOrientation` override. When the glasses are the source of
///      truth this stays off and the native head pose wins.
///
/// ### Why the Dart `registerVideoFrameObserver` path (not a native `IVideoFrameObserver`)
/// The [RtcEngine] is created and owned in Dart (`createAgoraRtcEngine`), so the officially supported,
/// version-stable way to tap remote frames is the Dart observer. Reaching the native
/// `agora::media::IVideoFrameObserver` would mean grabbing the plugin's internal native engine handle
/// and shipping C++/NDK — fragile across plugin versions and far more code. The one cost of the Dart
/// path — marshalling frame bytes across the platform channel — is bounded here by drop-stale
/// coalescing (only the newest frame is ever in flight), the exact mitigation the Insta360 frame
/// channel already proved necessary. The native observer remains the recommended latency optimisation
/// for production (documented in the build guide's Gaps/Risks).
class ViewerSphereView extends StatefulWidget {
  const ViewerSphereView({
    super.key,
    required this.engine,
    required this.remoteUid,
    this.enableGyroFallback = false,
  });

  /// The already-initialised, already-joined Agora engine from the live screen.
  final RtcEngine engine;

  /// The host's Agora UID whose ERP video we render. 0 means "any remote".
  final int remoteUid;

  /// Enable the device-gyroscope look-around fallback (for testing without glasses).
  final bool enableGyroFallback;

  static bool get supportsNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  State<ViewerSphereView> createState() => _ViewerSphereViewState();
}

class _ViewerSphereViewState extends State<ViewerSphereView> {
  static const MethodChannel _channel = MethodChannel('vyooo/viewer_sphere');

  VideoFrameObserver? _observer;

  // Drop-stale frame coalescing: keep only the newest frame; at most one in flight + one pending.
  VideoFrame? _pending;
  bool _inFlight = false;

  // Gyro fallback accumulation (degrees).
  GyroLookController? _gyro;
  double _yaw = 0;
  double _pitch = 0;

  @override
  void initState() {
    super.initState();
    if (ViewerSphereView.supportsNative) {
      _registerObserver();
      if (widget.enableGyroFallback) _startGyroFallback();
    }
  }

  @override
  void dispose() {
    _unregisterObserver();
    _gyro?.dispose();
    super.dispose();
  }

  // ── Agora frame observer ───────────────────────────────────────────────────────────────────────

  void _registerObserver() {
    final observer = VideoFrameObserver(
      onRenderVideoFrame: (String channelId, int remoteUid, VideoFrame frame) {
        if (widget.remoteUid != 0 && remoteUid != widget.remoteUid) return;
        // Keep only the latest frame; kick the pump if idle.
        _pending = frame;
        if (!_inFlight) _pump();
      },
    );
    _observer = observer;
    // Register on the media engine so remote frames are delivered pre-render.
    widget.engine.getMediaEngine().registerVideoFrameObserver(observer);
  }

  void _unregisterObserver() {
    final observer = _observer;
    if (observer != null) {
      widget.engine.getMediaEngine().unregisterVideoFrameObserver(observer);
      _observer = null;
    }
  }

  Future<void> _pump() async {
    final frame = _pending;
    _pending = null;
    if (frame == null) return;
    _inFlight = true;
    try {
      // Default remote frame format on Android is I420 (Y/U/V planes). Only forward complete planar
      // frames; other formats (RGBA pixelBuffer, textures) are not handled here.
      // TODO(hardware): verify the delivered VideoPixelFormat and add an RGBA path if the encoder
      // negotiates a different remote format.
      final y = frame.yBuffer;
      final u = frame.uBuffer;
      final v = frame.vBuffer;
      final w = frame.width;
      final h = frame.height;
      if (y != null && u != null && v != null && w != null && h != null && w > 0 && h > 0) {
        await _channel.invokeMethod<void>('submitFrame', <String, dynamic>{
          'y': y,
          'u': u,
          'v': v,
          'width': w,
          'height': h,
          'yStride': frame.yStride ?? w,
          'uStride': frame.uStride ?? (w ~/ 2),
          'vStride': frame.vStride ?? (w ~/ 2),
        });
      }
    } catch (e) {
      debugPrint('ViewerSphereView submitFrame failed: $e');
    } finally {
      _inFlight = false;
      // A newer frame arrived while we were sending → send it (drops everything in between).
      if (_pending != null) unawaited(_pump());
    }
  }

  // ── Gyro fallback (no glasses) ───────────────────────────────────────────────────────────────

  void _startGyroFallback() {
    final gyro = GyroLookController()
      ..onDelta = (dYaw, dPitch) {
        _yaw += dYaw;
        _pitch = (_pitch + dPitch).clamp(-89.0, 89.0);
        _channel.invokeMethod<void>('setViewOrientation', {'yaw': _yaw, 'pitch': _pitch});
      };
    gyro.start();
    _gyro = gyro;
  }

  @override
  Widget build(BuildContext context) {
    if (!ViewerSphereView.supportsNative) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text('XR sphere is Android-only',
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    // The native GL sphere. It samples the ERP frames pushed above and orients from the VITURE head
    // pose; on DP Alt Mode the phone mirrors this surface to the glasses.
    return const AndroidView(
      viewType: 'vyooo/viewer_sphere',
      creationParams: <String, dynamic>{},
      creationParamsCodec: StandardMessageCodec(),
    );
  }
}
