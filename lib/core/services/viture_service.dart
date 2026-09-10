import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A 3DoF head orientation sample from the VITURE glasses (Euler, degrees).
///
/// This is a *throttled* mirror for HUD/debug only — the actual head-tracked render is driven
/// natively (VitureManager → ViewerSphereRenderer) so Flutter is never in the motion-to-photon path.
@immutable
class VitureOrientation {
  const VitureOrientation({this.yaw = 0, this.pitch = 0, this.roll = 0});

  final double yaw;
  final double pitch;
  final double roll;
}

/// Observable state of the VITURE XR viewer.
@immutable
class VitureState {
  const VitureState({
    this.supported = false,
    this.connected = false,
    this.imuEnabled = false,
    this.orientation = const VitureOrientation(),
    this.lastError,
  });

  /// Device meets the SDK's baseline (Android 9+). Real availability is only known after [connect].
  final bool supported;

  /// SDK initialised and the IMU callback registered (i.e. glasses usable).
  final bool connected;
  final bool imuEnabled;
  final VitureOrientation orientation;
  final String? lastError;

  VitureState copyWith({
    bool? supported,
    bool? connected,
    bool? imuEnabled,
    VitureOrientation? orientation,
    String? lastError,
  }) {
    return VitureState(
      supported: supported ?? this.supported,
      connected: connected ?? this.connected,
      imuEnabled: imuEnabled ?? this.imuEnabled,
      orientation: orientation ?? this.orientation,
      lastError: lastError,
    );
  }
}

/// Dart wrapper over the native VITURE bridge (`vyooo/viture`).
///
/// Deliberately mirrors [Insta360LiveService]'s shape: control methods that never throw, plus a
/// [ValueNotifier] of observable [VitureState] fed by the `vyooo/viture/events` event channel. Knows
/// nothing about Agora or the sphere renderer — it only manages the head-tracking device.
class VitureService {
  VitureService();

  static const MethodChannel _methods = MethodChannel('vyooo/viture');
  static const EventChannel _events = EventChannel('vyooo/viture/events');

  final ValueNotifier<VitureState> state = ValueNotifier<VitureState>(const VitureState());

  StreamSubscription<dynamic>? _eventsSub;

  /// Begin listening to native connection/orientation events. Safe to call once.
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

  /// Whether this device meets the VITURE SDK baseline (Android 9+). Cheap capability check.
  Future<bool> isSupported() async {
    final ok = await _methods.invokeMethod<bool>('isSupported') ?? false;
    _update(state.value.copyWith(supported: ok));
    return ok;
  }

  /// Initialise the SDK + IMU (with USB-permission pre-flight on the native side).
  ///
  /// Never throws. The real connect outcome may arrive asynchronously on the event channel as a
  /// `startResult`/`connection` event (e.g. after the user answers the USB permission dialog).
  Future<bool> connect() async {
    try {
      final raw = await _methods.invokeMethod<Map<dynamic, dynamic>>('start');
      final status = raw?['status'] as String?;
      // 'started' → immediate success; 'awaiting_usb_permission' → wait for the event.
      return status == 'started';
    } on PlatformException catch (e) {
      _update(state.value.copyWith(lastError: e.message ?? e.code));
      return false;
    }
  }

  Future<void> disconnect() => _methods.invokeMethod<void>('stop');

  Future<bool> isConnected() async =>
      await _methods.invokeMethod<bool>('isConnected') ?? false;

  Future<void> setImuEnabled(bool enabled) async {
    await _methods.invokeMethod<void>('setImuEnabled', {'enabled': enabled});
    _update(state.value.copyWith(imuEnabled: enabled));
  }

  Future<Map<String, dynamic>> getStatus() async {
    final raw = await _methods.invokeMethod<Map<dynamic, dynamic>>('getStatus');
    return raw == null ? <String, dynamic>{} : raw.cast<String, dynamic>();
  }

  void _onEvent(dynamic raw) {
    final m = (raw as Map).cast<String, dynamic>();
    switch (m['event'] as String?) {
      case 'connection':
        _update(state.value.copyWith(connected: m['connected'] as bool? ?? false));
      case 'startResult':
        final ok = m['ok'] as bool? ?? false;
        _update(state.value.copyWith(connected: ok));
      case 'orientation':
        _update(state.value.copyWith(
          orientation: VitureOrientation(
            yaw: (m['yaw'] as num?)?.toDouble() ?? 0,
            pitch: (m['pitch'] as num?)?.toDouble() ?? 0,
            roll: (m['roll'] as num?)?.toDouble() ?? 0,
          ),
        ));
      case 'sdkEvent':
        debugPrint('VITURE sdkEvent id=${m['id']}');
      case 'error':
        _update(state.value.copyWith(lastError: m['message'] as String? ?? '${m['code']}'));
      default:
        break;
    }
  }

  void _update(VitureState next) => state.value = next;
}
