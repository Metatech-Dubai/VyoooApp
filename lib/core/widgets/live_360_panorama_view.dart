import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:dchs_motion_sensors/dchs_motion_sensors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';
import 'package:path_provider/path_provider.dart';

import '../services/device_motion_tracker.dart';
import '../services/live_360_snapshot_hub.dart';
import '../utils/equirectangular_sphere_mesh.dart';

/// Controls an attached [Live360PanoramaView] (e.g. gyro recalibration).
class Live360PanoramaViewController {
  VoidCallback? _onRecalibrate;

  bool get isAttached => _onRecalibrate != null;

  void recalibrateGyro() {
    _onRecalibrate?.call();
  }

  void _attach(VoidCallback onRecalibrate) {
    _onRecalibrate = onRecalibrate;
  }

  void _detach() {
    _onRecalibrate = null;
  }
}

/// Spherical 360° live viewer with gyro look-around.
class Live360PanoramaView extends StatefulWidget {
  const Live360PanoramaView({
    super.key,
    required this.rtcEngine,
    required this.remoteUid,
    required this.channelId,
    this.controller,
    this.gyroEnabled = true,
    this.touchEnabled = true,
    this.snapshotIntervalMs = 200,
  });

  final RtcEngine rtcEngine;
  final int remoteUid;
  final String channelId;
  final Live360PanoramaViewController? controller;
  final bool gyroEnabled;
  final bool touchEnabled;
  final int snapshotIntervalMs;

  @override
  State<Live360PanoramaView> createState() => _Live360PanoramaViewState();
}

class _Live360PanoramaViewState extends State<Live360PanoramaView>
    with SingleTickerProviderStateMixin {
  static const double _radius = 500;
  static const double _damping = 0.08;

  final DeviceMotionTracker _motionTracker = DeviceMotionTracker();
  final StreamController<void> _renderTick = StreamController<void>.broadcast();

  Scene? _scene;
  Object? _surface;
  VoidCallback? _motionListener;

  late AnimationController _animController;
  double _latitudeRad = 0;
  double _longitudeRad = 0;
  double _latitudeDelta = 0;
  double _longitudeDelta = 0;
  double _zoomDelta = 0;
  double _lookOffsetLon = 0;
  double _lookOffsetLat = 0;

  final Vector3 _fusedOrientation = Vector3(0, radians(90), 0);
  Vector3? _fusedOrientationBaseline;
  double _screenOrientationRad = 0;
  bool _useFusedOrientation = false;

  StreamSubscription<OrientationEvent>? _orientationSub;
  StreamSubscription<ScreenOrientationEvent>? _screenOrientSub;
  Timer? _captureTimer;
  bool _snapshotInFlight = false;
  int _framesApplied = 0;
  int _snapshotFailures = 0;
  ui.Image? _placeholderTexture;

  late final Future<void> Function(String path, int errCode) _snapshotHandler =
      _onSnapshotDelivered;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(minutes: 1),
      vsync: this,
    )..addListener(_updateView);
    _animController.repeat();
    Live360SnapshotHub.instance.bind(_snapshotHandler);
    unawaited(_loadPlaceholderTexture());
    _syncSensors();
    _startCaptureLoop();
    widget.controller?._attach(_recalibrateGyro);
  }

  void _recalibrateGyro() {
    _latitudeDelta = 0;
    _longitudeDelta = 0;
    _zoomDelta = 0;

    if (widget.gyroEnabled && _motionTracker.isAvailable.value) {
      final touchLat = _latitudeRad.clamp(
        -math.pi / 2 + 0.05,
        math.pi / 2 - 0.05,
      );
      final gyroSample = _motionTracker.sample.value;
      _lookOffsetLon += _longitudeRad + gyroSample.yaw;
      _lookOffsetLat += touchLat + gyroSample.pitch;

      _latitudeRad = 0;
      _longitudeRad = 0;
      _motionTracker.calibrate();
      _fusedOrientationBaseline = null;
    } else if (widget.gyroEnabled && _useFusedOrientation) {
      // Keep touch pan — only rebaseline fused device orientation.
      _fusedOrientationBaseline = Vector3.copy(_fusedOrientation);
    } else {
      _lookOffsetLon += _longitudeRad;
      _lookOffsetLat += _latitudeRad.clamp(
        -math.pi / 2 + 0.05,
        math.pi / 2 - 0.05,
      );
      _latitudeRad = 0;
      _longitudeRad = 0;
      _fusedOrientationBaseline = null;
    }

    _updateView();
  }

  @override
  void didUpdateWidget(covariant Live360PanoramaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(_recalibrateGyro);
    }
    if (oldWidget.remoteUid != widget.remoteUid ||
        oldWidget.channelId != widget.channelId) {
      _framesApplied = 0;
      _snapshotFailures = 0;
      _motionTracker.reset();
      _fusedOrientationBaseline = null;
      _lookOffsetLon = 0;
      _lookOffsetLat = 0;
    }
    if (oldWidget.gyroEnabled != widget.gyroEnabled) {
      _syncSensors();
    }
    if (oldWidget.snapshotIntervalMs != widget.snapshotIntervalMs) {
      _startCaptureLoop();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _captureTimer?.cancel();
    _orientationSub?.cancel();
    _screenOrientSub?.cancel();
    if (_motionListener != null) {
      _motionTracker.sample.removeListener(_motionListener!);
    }
    _motionTracker.dispose();
    _animController.dispose();
    _renderTick.close();
    Live360SnapshotHub.instance.unbind(_snapshotHandler);
    _placeholderTexture?.dispose();
    super.dispose();
  }

  Future<void> _loadPlaceholderTexture() async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const w = 4.0;
      const h = 2.0;
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF1A1A1A),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(w.toInt(), h.toInt());
      if (!mounted) {
        image.dispose();
        return;
      }
      _placeholderTexture = image;
      _applyTexture(image);
    } catch (_) {}
  }

  void _syncSensors() {
    _orientationSub?.cancel();
    _screenOrientSub?.cancel();
    if (_motionListener != null) {
      _motionTracker.sample.removeListener(_motionListener!);
      _motionListener = null;
    }

    if (kIsWeb || !widget.gyroEnabled) {
      _motionTracker.stop();
      _useFusedOrientation = false;
      return;
    }

    unawaited(_motionTracker.start());
    _motionListener = () {
      if (mounted) _updateView();
    };
    _motionTracker.sample.addListener(_motionListener!);

    motionSensors.orientationUpdateInterval =
        Duration.microsecondsPerSecond ~/ 60;
    _orientationSub = motionSensors.orientation.listen((event) {
      _fusedOrientation.setValues(event.yaw, event.pitch, event.roll);
      _useFusedOrientation = true;
    });
    _screenOrientSub = motionSensors.screenOrientation.listen((event) {
      _screenOrientationRad = radians(event.angle ?? 0);
    });
  }

  void _startCaptureLoop() {
    _captureTimer?.cancel();
    final interval = Duration(
      milliseconds: widget.snapshotIntervalMs.clamp(120, 500),
    );
    _captureTimer = Timer.periodic(interval, (_) {
      unawaited(_requestSnapshot());
    });
    unawaited(_requestSnapshot());
  }

  Future<void> _requestSnapshot() async {
    if (_snapshotInFlight || !mounted || widget.remoteUid == 0) return;

    _snapshotInFlight = true;
    String? filePath;
    try {
      final dir = await getTemporaryDirectory();
      filePath =
          '${dir.path}/live360_${widget.channelId}_${widget.remoteUid}_'
          '${DateTime.now().millisecondsSinceEpoch}.jpg';
      Live360SnapshotHub.instance.arm(filePath);
      await widget.rtcEngine.takeSnapshot(
        uid: widget.remoteUid,
        filePath: filePath,
      );
      unawaited(
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (mounted && _snapshotInFlight) {
            _snapshotInFlight = false;
          }
        }),
      );
    } catch (e) {
      _snapshotFailures++;
      if (_snapshotFailures <= 3 || _snapshotFailures % 20 == 0) {
        debugPrint('[Live360Panorama] takeSnapshot failed: $e');
      }
      if (filePath != null) {
        try {
          await File(filePath).delete();
        } catch (_) {}
      }
      _snapshotInFlight = false;
    }
  }

  Future<void> _onSnapshotDelivered(String filePath, int errCode) async {
    _snapshotInFlight = false;
    if (!mounted) return;

    try {
      if (errCode != 0) {
        _snapshotFailures++;
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }

      final firstFrame = _framesApplied == 0;
      _applyTexture(frame.image);
      _framesApplied++;
      _snapshotFailures = 0;
      if (firstFrame) {
        debugPrint(
          '[Live360Panorama] first frame ${frame.image.width}x'
          '${frame.image.height} platform=${Platform.operatingSystem}',
        );
        setState(() {});
      }
    } catch (e) {
      _snapshotFailures++;
      if (_snapshotFailures <= 3 || _snapshotFailures % 20 == 0) {
        debugPrint('[Live360Panorama] decode failed: $e');
      }
    } finally {
      try {
        await File(filePath).delete();
      } catch (_) {}
    }
  }

  void _applyTexture(ui.Image image) {
    final surface = _surface;
    final scene = _scene;
    if (surface == null || scene == null) return;

    final previous = surface.mesh.texture;
    surface.mesh.texture = image;
    surface.mesh.textureRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    scene.texture = image;
    scene.updateTexture();
    if (previous != null && previous != _placeholderTexture) {
      previous.dispose();
    }
    scene.update();
    _renderTick.add(null);
  }

  void _onSceneCreated(Scene scene) {
    _scene = scene;
    scene.camera.near = 0.01;
    scene.camera.far = _radius + 1;
    scene.camera.fov = 75;
    scene.camera.zoom = 1;
    scene.camera.position.setFrom(Vector3(0, 0, 0.01));

    final mesh = buildEquirectangularSphereMesh(
      radius: _radius,
      texture: _placeholderTexture,
    );
    _surface = Object(
      name: 'live360',
      mesh: mesh,
      backfaceCulling: true,
    );
    scene.world.add(_surface!);
    _updateView();
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
  }

  late Offset _lastFocalPoint;

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.touchEnabled) return;
    final scene = _scene;
    if (scene == null) return;

    final offset = details.localFocalPoint - _lastFocalPoint;
    _lastFocalPoint = details.localFocalPoint;
    final viewport = math.max(scene.camera.viewportHeight, 1.0);
    _latitudeDelta += 0.5 * math.pi * offset.dy / viewport;
    _longitudeDelta -= 0.5 * math.pi * offset.dx / viewport;
  }

  void _updateView() {
    final scene = _scene;
    if (scene == null) return;

    _latitudeRad += _latitudeDelta * _damping;
    _latitudeDelta *= 1 - _damping;
    _longitudeRad += _longitudeDelta * _damping;
    _longitudeDelta *= 1 - _damping;

    final zoom = (scene.camera.zoom + _zoomDelta * _damping).clamp(1.0, 3.0);
    _zoomDelta *= 1 - _damping;
    scene.camera.zoom = zoom;

    final touchLat =
        _latitudeRad.clamp(-math.pi / 2 + 0.05, math.pi / 2 - 0.05);
    final touchLon = _longitudeRad;

    var q = Quaternion.axisAngle(Vector3(0, 0, 1), _screenOrientationRad);

    if (widget.gyroEnabled && _motionTracker.isAvailable.value) {
      final gyroLon = _motionTracker.sample.value.yaw;
      final gyroLat = _motionTracker.sample.value.pitch;
      final totalLon = touchLon + gyroLon + _lookOffsetLon;
      final totalLat = touchLat + gyroLat + _lookOffsetLat;
      q *= Quaternion.axisAngle(Vector3(0, 1, 0), totalLon);
      q = Quaternion.axisAngle(Vector3(1, 0, 0), -totalLat) * q;
    } else if (widget.gyroEnabled && _useFusedOrientation) {
      final baseline = _fusedOrientationBaseline;
      final yaw = baseline == null
          ? _fusedOrientation.x
          : _fusedOrientation.x - baseline.x;
      final pitch = baseline == null
          ? _fusedOrientation.y
          : _fusedOrientation.y - baseline.y;
      final roll = baseline == null
          ? _fusedOrientation.z
          : _fusedOrientation.z - baseline.z;

      q *= Quaternion.euler(-roll, -pitch, -yaw);
      q *= Quaternion.axisAngle(Vector3(1, 0, 0), math.pi * 0.5);

      var o = _quaternionToOrientation(q);
      const minLat = -math.pi / 2 + 0.05;
      const maxLat = math.pi / 2 - 0.05;
      final lat = (-o.y).clamp(minLat, maxLat);
      final lon = o.x;
      o.x = lon;
      o.y = -lat;
      q = _orientationToQuaternion(o);

      q *= Quaternion.axisAngle(Vector3(0, 1, 0), -math.pi * 0.5);
      q *= Quaternion.axisAngle(Vector3(0, 1, 0), touchLon);
      q = Quaternion.axisAngle(Vector3(1, 0, 0), -touchLat) * q;
    } else {
      final totalLon = touchLon + _lookOffsetLon;
      final totalLat = touchLat + _lookOffsetLat;
      q *= Quaternion.axisAngle(Vector3(0, 1, 0), totalLon);
      q = Quaternion.axisAngle(Vector3(1, 0, 0), -totalLat) * q;
    }

    q.rotate(scene.camera.target..setFrom(Vector3(0, 0, -_radius)));
    q.rotate(scene.camera.up..setFrom(Vector3(0, 1, 0)));
    scene.update();
    _renderTick.add(null);
  }

  Vector3 _quaternionToOrientation(Quaternion q) {
    final x = q.storage[0];
    final y = q.storage[1];
    final z = q.storage[2];
    final w = q.storage[3];
    final pitch = math.asin(2 * (y * z + w * x));
    final yaw = math.atan2(-2 * (x * z - w * y), 1 - 2 * (x * x + y * y));
    final roll = math.atan2(-2 * (x * y - w * z), 1 - 2 * (x * x + z * z));
    return Vector3(yaw, pitch, roll);
  }

  Quaternion _orientationToQuaternion(Vector3 v) {
    final m = Matrix4.identity()
      ..rotateZ(v.z)
      ..rotateX(v.y)
      ..rotateY(v.x);
    return Quaternion.fromRotation(m.getRotation());
  }

  @override
  Widget build(BuildContext context) {
    Widget sphere = Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        Cube(
          key: const ValueKey('live360_cube'),
          interactive: false,
          onSceneCreated: _onSceneCreated,
        ),
        if (_framesApplied == 0)
          const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
      ],
    );

    if (widget.touchEnabled) {
      sphere = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
        child: sphere,
      );
    }

    return sphere;
  }
}
