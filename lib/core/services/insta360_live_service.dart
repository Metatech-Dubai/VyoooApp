import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How the phone connects to the Insta360 camera.
enum Insta360ConnectType { usb, wifi }

/// Outcome of a [Insta360LiveService.connect] call.
///
/// `connect` is only the *start* of the handshake — the SDK's `openCamera()` is asynchronous, so
/// [connecting] means "the open was dispatched", not "connected". The real outcome arrives later as
/// a `connection` or `error` event.
enum Insta360ConnectOutcome {
  /// The SDK open was dispatched; wait for the connection event.
  connecting,

  /// The Android USB permission dialog is up; the open runs once the user accepts.
  /// Expect a longer wait than a normal connect (the user has to answer a system dialog).
  awaitingUsbPermission,

  /// A session is already open — the caller must NOT re-enter (a second `openCamera()` at a camera
  /// mid-session is what leaves the stuck session behind SDK error 4403).
  alreadyConnected,

  /// A connect is already in flight (e.g. a double-tap on the picker). Same rule as above.
  alreadyConnecting,

  /// Rejected up-front. [Insta360State.lastError] carries a human-readable cause + remedy.
  failed,
}

/// A single extracted, stitched ERP frame (used by the debug Agora preview).
@immutable
class Insta360Frame {
  const Insta360Frame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.ptsUs,
  });

  /// RGBA pixel bytes (`width * height * 4`).
  final Uint8List bytes;
  final int width;
  final int height;

  /// Monotonic presentation timestamp in microseconds.
  final int ptsUs;
}

/// Observable state of the Insta360 capture foundation.
@immutable
class Insta360State {
  const Insta360State({
    this.supported = false,
    this.connected = false,
    this.connectType = 0,
    this.streaming = false,
    this.previewReady = false,
    this.frameWidth,
    this.frameHeight,
    this.fps,
    this.frameCount = 0,
    this.lastError,
  });

  final bool supported;
  final bool connected;
  final int connectType;
  final bool streaming;

  /// True once the host preview has finished establishing (initial render + the warm refresh that
  /// corrects the first-connect seam overlap). The UI covers the preview until this flips true.
  final bool previewReady;
  final int? frameWidth;
  final int? frameHeight;
  final int? fps;
  final int frameCount;
  final String? lastError;

  Insta360State copyWith({
    bool? supported,
    bool? connected,
    int? connectType,
    bool? streaming,
    bool? previewReady,
    int? frameWidth,
    int? frameHeight,
    int? fps,
    int? frameCount,
    String? lastError,
  }) {
    return Insta360State(
      supported: supported ?? this.supported,
      connected: connected ?? this.connected,
      connectType: connectType ?? this.connectType,
      streaming: streaming ?? this.streaming,
      previewReady: previewReady ?? this.previewReady,
      frameWidth: frameWidth ?? this.frameWidth,
      frameHeight: frameHeight ?? this.frameHeight,
      fps: fps ?? this.fps,
      frameCount: frameCount ?? this.frameCount,
      lastError: lastError,
    );
  }
}

/// Dart wrapper over the native Insta360 capture bridge.
///
/// Pure plumbing: connection control, status/stats stream, and a raw-frame stream. It deliberately
/// knows nothing about Agora or the optimisation pipeline.
class Insta360LiveService {
  Insta360LiveService();

  static const MethodChannel _methods = MethodChannel('vyooo/insta360');
  static const EventChannel _events = EventChannel('vyooo/insta360/events');
  static const EventChannel _frames = EventChannel('vyooo/insta360/frames');

  final ValueNotifier<Insta360State> state =
      ValueNotifier<Insta360State>(const Insta360State());

  /// Safety net: if the native "ready" signal is ever lost, drop the connecting overlay anyway.
  static const Duration _previewReadyTimeout = Duration(seconds: 10);

  StreamSubscription<dynamic>? _eventsSub;
  Timer? _previewReadyFallback;

  /// Begin listening to native status/stat events. Safe to call once.
  void start() {
    _eventsSub ??= _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object e) => _update(state.value.copyWith(lastError: '$e')),
    );
  }

  Future<void> dispose() async {
    _previewReadyFallback?.cancel();
    await _eventsSub?.cancel();
    _eventsSub = null;
    state.dispose();
  }

  Future<bool> isSupported() async {
    final ok = await _methods.invokeMethod<bool>('isSupported') ?? false;
    _update(state.value.copyWith(supported: ok));
    return ok;
  }

  /// Ask the native bridge to open the camera.
  ///
  /// Never throws: a pre-flight rejection (no USB device, not on the camera's Wi-Fi, unsupported
  /// model) comes back as [Insta360ConnectOutcome.failed] with the remedy in [Insta360State.lastError],
  /// immediately — not after a timeout.
  Future<Insta360ConnectOutcome> connect(Insta360ConnectType type) async {
    try {
      final raw = await _methods.invokeMethod<Map<dynamic, dynamic>>('connect', {
        'type': type == Insta360ConnectType.wifi ? 'wifi' : 'usb',
      });
      switch (raw?['status'] as String?) {
        case 'awaiting_usb_permission':
          return Insta360ConnectOutcome.awaitingUsbPermission;
        case 'already_connected':
          return Insta360ConnectOutcome.alreadyConnected;
        case 'already_connecting':
          return Insta360ConnectOutcome.alreadyConnecting;
        case 'connecting':
          return Insta360ConnectOutcome.connecting;
        default:
          _update(state.value.copyWith(
            lastError: 'Could not start the 360 camera connection.',
          ));
          return Insta360ConnectOutcome.failed;
      }
    } on PlatformException catch (e) {
      // Native already maps SDK/pre-flight codes to a human cause + remedy (T3).
      _update(state.value.copyWith(lastError: e.message ?? e.code));
      return Insta360ConnectOutcome.failed;
    }
  }

  Future<void> disconnect() => _methods.invokeMethod<void>('disconnect');

  Future<void> setFrameStreaming(bool enabled) async {
    await _methods.invokeMethod<void>('setFrameStreaming', {'enabled': enabled});
    _update(state.value.copyWith(streaming: enabled));
  }

  Future<Map<String, dynamic>> getStatus() async {
    final raw = await _methods.invokeMethod<Map<dynamic, dynamic>>('getStatus');
    return raw == null ? <String, dynamic>{} : raw.cast<String, dynamic>();
  }

  /// Latest pipeline metrics (fps, per-stage latency, spatial reduction); empty when off.
  Future<Map<String, dynamic>> getPipelineMetrics() async {
    final raw =
        await _methods.invokeMethod<Map<dynamic, dynamic>>('getPipelineMetrics');
    return raw == null ? <String, dynamic>{} : raw.cast<String, dynamic>();
  }

  /// Allocate a Flutter texture fed by the pipeline's processed frames (host preview).
  /// Returns the texture id for a `Texture(textureId: …)` widget, or null on failure.
  Future<int?> createProcessedTexture() =>
      _methods.invokeMethod<int>('createProcessedTexture');

  /// Release the processed-frame texture and stop host-side rendering.
  Future<void> disposeProcessedTexture() =>
      _methods.invokeMethod<void>('disposeProcessedTexture');

  /// Toggle forward-only masking on the live 360 feed (true = masked, false = full 360°).
  Future<void> setMaskEnabled(bool enabled) =>
      _methods.invokeMethod<void>('setMaskEnabled', {'enabled': enabled});

  /// Toggle temporal redundancy reduction (1-in-N + motion gating) on the live 360 feed. Off
  /// transmits every frame — used for A/B bitrate comparison. Metrics are read via
  /// [getPipelineMetrics] (`keepRatio`, `motionKeeps`, `framesKept`, …).
  Future<void> setTemporalEnabled(bool enabled) =>
      _methods.invokeMethod<void>('setTemporalEnabled', {'enabled': enabled});

  /// Toggle the M3 heuristic AI decision layer. Off = deterministic fall-open. Its signals and cost
  /// are read via [getPipelineMetrics] (`aiEnabled`, `aiMotion`, `aiRecommendedScale`,
  /// `aiOverheadMs`, …). Used for A/B demonstration of adaptive behavior.
  Future<void> setAiEnabled(bool enabled) =>
      _methods.invokeMethod<void>('setAiEnabled', {'enabled': enabled});

  /// Point the interactive 360 view at an absolute orientation, in degrees. Drives the SDK
  /// player's `setYaw`/`setPitch` so the host can drag to look around. Fire-and-forget.
  Future<void> setViewOrientation(double yaw, double pitch) {
    return _methods.invokeMethod<void>('setViewOrientation', {
      'yaw': yaw,
      'pitch': pitch,
    });
  }

  /// Raw ERP frames (debug). Enable forwarding first via [setFrameStreaming].
  Stream<Insta360Frame> frames() {
    return _frames.receiveBroadcastStream().map((dynamic e) {
      final m = (e as Map).cast<String, dynamic>();
      return Insta360Frame(
        bytes: m['bytes'] as Uint8List,
        width: m['width'] as int,
        height: m['height'] as int,
        ptsUs: (m['ptsUs'] as num).toInt(),
      );
    });
  }

  void _onEvent(dynamic raw) {
    final m = (raw as Map).cast<String, dynamic>();
    switch (m['event'] as String?) {
      case 'connection':
        final connected = m['connected'] as bool? ?? false;
        if (!connected) {
          _previewReadyFallback?.cancel();
        }
        _update(state.value.copyWith(
          connected: connected,
          connectType: (m['connectType'] as num?)?.toInt() ?? 0,
          // A dropped camera invalidates any established preview.
          previewReady: connected ? state.value.previewReady : false,
        ));
      case 'previewState':
        final ready = (m['state'] as String?) == 'ready';
        _previewReadyFallback?.cancel();
        if (!ready) {
          // "warming": hold the overlay, but never let it stick if "ready" is lost.
          _previewReadyFallback = Timer(_previewReadyTimeout, () {
            _update(state.value.copyWith(previewReady: true));
          });
        }
        _update(state.value.copyWith(previewReady: ready));
      case 'frameStats':
        _update(state.value.copyWith(
          frameWidth: (m['width'] as num?)?.toInt(),
          frameHeight: (m['height'] as num?)?.toInt(),
          fps: (m['fps'] as num?)?.toInt(),
          frameCount: (m['count'] as num?)?.toInt() ?? state.value.frameCount,
        ));
      case 'error':
        // Native maps the raw SDK code to a cause + remedy (T3) and keeps the code in logcat.
        // Fall back to the raw code only if an older/native path sent no message.
        final message = m['message'] as String?;
        _update(state.value.copyWith(
          lastError: message ?? 'native error: ${m['scope']} ${m['code']}',
        ));
      case 'connectRetry':
        // Informational: the native side is retrying a transient handshake failure with backoff.
        debugPrint(
          'Insta360: retrying connect after error ${m['code']} '
          '(attempt ${m['attempt']}/${m['max']})',
        );
      default:
        break;
    }
  }

  void _update(Insta360State next) => state.value = next;
}
