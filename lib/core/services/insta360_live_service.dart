import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How the phone connects to the Insta360 camera.
enum Insta360ConnectType { usb, wifi }

/// A single extracted, stitched ERP frame (used only by the Phase-0 Agora spike).
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
      frameWidth: frameWidth ?? this.frameWidth,
      frameHeight: frameHeight ?? this.frameHeight,
      fps: fps ?? this.fps,
      frameCount: frameCount ?? this.frameCount,
      lastError: lastError,
    );
  }
}

/// Dart wrapper over the native Insta360 capture bridge (Phase 0 foundation).
///
/// Pure plumbing: connection control, status/stats stream, and a raw-frame stream for the
/// Agora de-risk spike. It deliberately knows nothing about Agora or the optimisation pipeline.
class Insta360LiveService {
  Insta360LiveService();

  static const MethodChannel _methods = MethodChannel('vyooo/insta360');
  static const EventChannel _events = EventChannel('vyooo/insta360/events');
  static const EventChannel _frames = EventChannel('vyooo/insta360/frames');

  final ValueNotifier<Insta360State> state =
      ValueNotifier<Insta360State>(const Insta360State());

  StreamSubscription<dynamic>? _eventsSub;

  /// Begin listening to native status/stat events. Safe to call once.
  void start() {
    _eventsSub ??= _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object e) => _update(state.value.copyWith(lastError: '$e')),
    );
  }

  Future<void> dispose() async {
    await _eventsSub?.cancel();
    _eventsSub = null;
    state.dispose();
  }

  Future<bool> isSupported() async {
    final ok = await _methods.invokeMethod<bool>('isSupported') ?? false;
    _update(state.value.copyWith(supported: ok));
    return ok;
  }

  Future<bool> connect(Insta360ConnectType type) async {
    try {
      final ok = await _methods.invokeMethod<bool>('connect', {
        'type': type == Insta360ConnectType.wifi ? 'wifi' : 'usb',
      });
      return ok ?? false;
    } on PlatformException catch (e) {
      _update(state.value.copyWith(lastError: e.message ?? e.code));
      return false;
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

  /// Raw ERP frames for the spike. Enable forwarding first via [setFrameStreaming].
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
        _update(state.value.copyWith(
          connected: m['connected'] as bool? ?? false,
          connectType: (m['connectType'] as num?)?.toInt() ?? 0,
        ));
      case 'frameStats':
        _update(state.value.copyWith(
          frameWidth: (m['width'] as num?)?.toInt(),
          frameHeight: (m['height'] as num?)?.toInt(),
          fps: (m['fps'] as num?)?.toInt(),
          frameCount: (m['count'] as num?)?.toInt() ?? state.value.frameCount,
        ));
      case 'error':
        _update(state.value.copyWith(
          lastError: 'native error: ${m['scope']} ${m['code']}',
        ));
      default:
        break;
    }
  }

  void _update(Insta360State next) => state.value = next;
}
