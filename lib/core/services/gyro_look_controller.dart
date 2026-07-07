import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

/// Fuses the device gyroscope into incremental yaw/pitch (degrees) for 360
/// look-around. Shared by the host preview and (later) the viewer sphere.
///
/// Emits *deltas* via [onDelta] so it composes with the touch/slider controls
/// (both simply add to the same accumulated yaw/pitch). Integrates angular rate
/// over the real time between samples; long gaps are skipped to avoid jumps.
class GyroLookController {
  GyroLookController({this.sensitivity = 1.0});

  /// Scales how far the view turns per unit of device rotation.
  final double sensitivity;

  /// Called with each (dYaw, dPitch) increment in degrees while active.
  void Function(double dYaw, double dPitch)? onDelta;

  StreamSubscription<GyroscopeEvent>? _sub;
  DateTime? _last;

  static const double _radToDeg = 57.2957795;
  static const double _deadZoneRadPerSec = 0.02;

  bool get isActive => _sub != null;

  void start() {
    if (_sub != null) return;
    _last = null;
    // ~50 Hz sampling: the default (normalInterval, ~5 Hz) delivers large,
    // steppy jumps. gameInterval makes the look-around smooth.
    _sub = gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval)
        .listen(_onEvent);
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _last = null;
  }

  void _onEvent(GyroscopeEvent e) {
    final now = DateTime.now();
    final last = _last;
    _last = now;
    if (last == null) return;
    final dt = now.difference(last).inMicroseconds / 1e6;
    // Skip zero/negative dt and long gaps (e.g. after a pause) to avoid jumps.
    if (dt <= 0 || dt > 0.2) return;
    // Dead zone: ignore small rotation rates so a hand-held phone doesn't drift
    // from sensor jitter (rad/s).
    final rx = e.x.abs() < _deadZoneRadPerSec ? 0.0 : e.x;
    final ry = e.y.abs() < _deadZoneRadPerSec ? 0.0 : e.y;
    if (rx == 0.0 && ry == 0.0) return;
    // Portrait hold: rotating the phone about its vertical (y) axis pans yaw;
    // tilting about the x axis pans pitch. Sign chosen so the view follows the
    // device (rotate phone right → view pans right).
    final dYaw = ry * dt * _radToDeg * sensitivity;
    final dPitch = rx * dt * _radToDeg * sensitivity;
    onDelta?.call(dYaw, dPitch);
  }

  void dispose() => stop();
}
