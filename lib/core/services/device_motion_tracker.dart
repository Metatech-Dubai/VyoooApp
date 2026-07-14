import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Device yaw/pitch sample for immersive live viewing (radians).
@immutable
class DeviceMotionSample {
  const DeviceMotionSample({
    required this.yaw,
    required this.pitch,
    required this.timestamp,
  });

  /// Horizontal look angle in radians (0 = center).
  final double yaw;

  /// Vertical look angle in radians (0 = horizon).
  final double pitch;

  final DateTime timestamp;

  static final zero = DeviceMotionSample(
    yaw: 0,
    pitch: 0,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Gyroscope-driven orientation tracker with light smoothing.
///
/// Call [start] when the viewer surface is visible and [stop] on dispose /
/// background / inactive tab.
class DeviceMotionTracker {
  DeviceMotionTracker({
    this.maxPitchRad = math.pi / 2.5,
    this.smoothingFactor = 0.12,
  });

  final double maxPitchRad;
  final double smoothingFactor;

  final ValueNotifier<DeviceMotionSample> sample =
      ValueNotifier<DeviceMotionSample>(DeviceMotionSample.zero);

  /// True when gyro/accelerometer streams are running.
  final ValueNotifier<bool> isAvailable = ValueNotifier<bool>(false);

  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  double _yaw = 0;
  double _pitch = 0;
  double _filteredYaw = 0;
  double _filteredPitch = 0;
  double _yawBaseline = 0;
  double _pitchBaseline = 0;
  DateTime? _lastGyroAt;
  bool _startAttempted = false;

  bool get isActive => _gyroSub != null;

  /// Starts motion tracking. No-op after a permanent plugin failure.
  Future<void> start() async {
    if (_gyroSub != null || kIsWeb || (_startAttempted && !isAvailable.value)) {
      return;
    }
    _startAttempted = true;

    try {
      _lastGyroAt = DateTime.now();
      _gyroSub = gyroscopeEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        _onGyroscope,
        onError: _onStreamError,
        cancelOnError: true,
      );

      _accelSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen(
        _onAccelerometer,
        onError: _onStreamError,
        cancelOnError: true,
      );
      isAvailable.value = true;
    } on MissingPluginException catch (e, st) {
      _handleUnavailable(e, st);
    } on PlatformException catch (e, st) {
      _handleUnavailable(e, st);
    }
  }

  void stop() {
    _gyroSub?.cancel();
    _gyroSub = null;
    _accelSub?.cancel();
    _accelSub = null;
    _lastGyroAt = null;
    if (!isAvailable.value) {
      _startAttempted = false;
    }
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    _handleUnavailable(error, stackTrace);
  }

  void _handleUnavailable(Object error, StackTrace stackTrace) {
    debugPrint('[DeviceMotionTracker] sensors unavailable: $error');
    stop();
    isAvailable.value = false;
  }

  void reset() {
    _yaw = 0;
    _pitch = 0;
    _filteredYaw = 0;
    _filteredPitch = 0;
    _yawBaseline = 0;
    _pitchBaseline = 0;
    sample.value = DeviceMotionSample.zero;
  }

  /// Sets the current device orientation as the look-around center (0, 0).
  void calibrate() {
    _yawBaseline = _filteredYaw;
    _pitchBaseline = _filteredPitch;
    sample.value = DeviceMotionSample(
      yaw: 0,
      pitch: 0,
      timestamp: DateTime.now(),
    );
  }

  void dispose() {
    stop();
    sample.dispose();
    isAvailable.dispose();
  }

  void _onGyroscope(GyroscopeEvent event) {
    final now = DateTime.now();
    final last = _lastGyroAt;
    _lastGyroAt = now;
    if (last == null) return;

    final dt = now.difference(last).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.5) return;

    // Device coordinates: x = pitch axis, y = yaw axis (portrait hold).
    _pitch += event.x * dt;
    _yaw += event.y * dt;
    _pitch = _pitch.clamp(-maxPitchRad, maxPitchRad);

    _filteredPitch += ( _pitch - _filteredPitch) * smoothingFactor;
    _filteredYaw += (_yaw - _filteredYaw) * smoothingFactor;

    sample.value = DeviceMotionSample(
      yaw: _filteredYaw - _yawBaseline,
      pitch: _filteredPitch - _pitchBaseline,
      timestamp: now,
    );
  }

  void _onAccelerometer(AccelerometerEvent event) {
    // Gentle pitch stabilization from gravity vector.
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (magnitude < 1) return;

    final normX = event.x / magnitude;
    final normY = event.y / magnitude;
    final gravityPitch = math.atan2(normX, normY);
    _pitch = _pitch * 0.96 + gravityPitch * 0.04;
    _pitch = _pitch.clamp(-maxPitchRad, maxPitchRad);
  }
}
