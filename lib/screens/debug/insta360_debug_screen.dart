import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/agora_config.dart';
import '../../core/services/insta360_live_service.dart';
import '../../widgets/insta360_preview_view.dart';

/// Test harness for the Insta360 capture feature.
///
/// Not wired into production navigation — push it explicitly while testing, e.g.:
///   Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Insta360DebugScreen()));
///
/// Validates: connect → ERP preview → frame-extraction stats → frames into an Agora channel.
///
/// TODO(pre-production): retained as a debugging aid; remove or gate behind a debug-only build flag
/// before release — it is dead code at runtime today.
class Insta360DebugScreen extends StatefulWidget {
  const Insta360DebugScreen({super.key});

  @override
  State<Insta360DebugScreen> createState() => _Insta360DebugScreenState();
}

class _Insta360DebugScreenState extends State<Insta360DebugScreen> {
  final Insta360LiveService _service = Insta360LiveService();

  // ── Agora spike state ──────────────────────────────────────────────────────
  RtcEngine? _engine;
  StreamSubscription<Insta360Frame>? _frameSub;
  bool _spikeActive = false;
  int _pushedFrames = 0;
  String _spikeStatus = 'idle';
  final TextEditingController _channelCtrl =
      TextEditingController(text: 'insta360_spike');

  // ── Pipeline metrics state ─────────────────────────────────────────────────
  Map<String, dynamic> _metrics = const {};
  Timer? _metricsTimer;

  @override
  void initState() {
    super.initState();
    _service.start();
    _service.isSupported();
    // Poll pipeline metrics ~1×/sec for the real-time validation readout.
    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final m = await _service.getPipelineMetrics();
      if (mounted) setState(() => _metrics = m);
    });
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    _stopSpike();
    _service.disconnect();
    _service.dispose();
    _channelCtrl.dispose();
    super.dispose();
  }

  // ── Connection ───────────────────────────────────────────────────────────────
  Future<void> _connect(Insta360ConnectType type) async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await _service.connect(type);
  }

  // ── Agora test push ─────────────────────────────────────────────────────────
  // EXPERIMENTAL: pushes extracted ERP frames into Agora as an external video source.
  // Validate end-to-end on device with a second viewer; tune resolution if bandwidth-bound.
  Future<void> _startSpike() async {
    setState(() => _spikeStatus = 'starting…');
    try {
      await [Permission.microphone].request();

      final engine = createAgoraRtcEngine();
      await engine.initialize(const RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await engine.enableVideo();

      // Route extracted frames in as the video source instead of the device camera.
      await engine.getMediaEngine().setExternalVideoSource(
            enabled: true,
            useTexture: false,
            sourceType: ExternalVideoSourceType.videoFrame,
          );

      _frameSub = _service.frames().listen(_pushFrame);
      await _service.setFrameStreaming(true);

      await engine.joinChannel(
        token: '', // testing mode / temp token; wire AgoraTokenService for App-Certificate projects
        channelId: _channelCtrl.text.trim(),
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: true, // external video source publishes via the camera track
          publishMicrophoneTrack: false,
          autoSubscribeAudio: false,
          autoSubscribeVideo: false,
        ),
      );

      _engine = engine;
      setState(() {
        _spikeActive = true;
        _spikeStatus = 'pushing to "${_channelCtrl.text.trim()}"';
      });
    } catch (e) {
      setState(() => _spikeStatus = 'error: $e');
      await _stopSpike();
    }
  }

  void _pushFrame(Insta360Frame frame) {
    final engine = _engine;
    if (engine == null) return;
    engine
        .getMediaEngine()
        .pushVideoFrame(
          frame: ExternalVideoFrame(
            type: VideoBufferType.videoBufferRawData,
            format: VideoPixelFormat.videoPixelRgba,
            buffer: frame.bytes,
            stride: frame.width,
            height: frame.height,
            timestamp: frame.ptsUs ~/ 1000,
          ),
        )
        .then((_) {
      if (mounted && (++_pushedFrames % 30 == 0)) setState(() {});
    }).catchError((_) {});
  }

  Future<void> _stopSpike() async {
    await _frameSub?.cancel();
    _frameSub = null;
    await _service.setFrameStreaming(false);
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      try {
        await engine.leaveChannel();
        await engine.release();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _spikeActive = false;
        _spikeStatus = 'stopped';
      });
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A000F),
      appBar: AppBar(
        title: const Text('Insta360 — Debug'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: ValueListenableBuilder<Insta360State>(
        valueListenable: _service.state,
        builder: (context, s, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _statusCard(s),
              const SizedBox(height: 12),
              _connectionButtons(s),
              const SizedBox(height: 16),
              const Text('Preview (ERP 2:1)',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: s.connected
                      ? const Insta360PreviewView(extractWidth: 960, extractHeight: 480)
                      : const Center(
                          child: Text('Connect a camera to preview',
                              style: TextStyle(color: Colors.white38)),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              _pipelineCard(),
              const SizedBox(height: 16),
              _spikeCard(s),
            ],
          );
        },
      ),
    );
  }

  // ── Pipeline metrics ────────────────────────────────────────────────────────
  Widget _pipelineCard() {
    final fps = _metrics['fps'];
    final totalMs = (_metrics['totalMs'] as num?)?.toDouble();
    final reduction = (_metrics['spatialReduction'] as num?)?.toDouble();
    final framesIn = _metrics['framesIn'];
    final framesOut = _metrics['framesOut'];
    final dropped = _metrics['framesDropped'];
    final stages = (_metrics['stagesMs'] as Map?)?.cast<String, dynamic>();

    return _card([
      const Text('Optimisation pipeline',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      const Text('Single processing path: Downscale → PanoramaDetect → ForwardMask → TemporalDedup.',
          style: TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 8),
      _row('Pipeline fps', '${fps ?? 0}'),
      _row('Total latency', totalMs == null ? '—' : '${totalMs.toStringAsFixed(2)} ms'),
      _row(
        'Spatial reduction',
        reduction == null ? '—' : '${(reduction * 100).toStringAsFixed(0)}% px kept',
      ),
      _row('Frames in / out', '${framesIn ?? 0} / ${framesOut ?? 0}'),
      _row('Dropped', '${dropped ?? 0}'),
      if (stages != null && stages.isNotEmpty) ...[
        const SizedBox(height: 6),
        const Text('Per-stage (ms)',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        for (final e in stages.entries)
          _row('  ${e.key}',
              '${(e.value as num).toDouble().toStringAsFixed(2)} ms'),
      ],
    ]);
  }

  Widget _statusCard(Insta360State s) {
    final res = (s.frameWidth != null && s.frameHeight != null)
        ? '${s.frameWidth}×${s.frameHeight}'
        : '—';
    return _card([
      _row('Supported', s.supported ? 'yes' : 'no'),
      _row('Connected', s.connected ? 'yes (type ${s.connectType})' : 'no'),
      _row('Frame size', res),
      _row('FPS', '${s.fps ?? 0}'),
      _row('Frames', '${s.frameCount}'),
      _row('Streaming', s.streaming ? 'on' : 'off'),
      if (s.lastError != null) _row('Error', s.lastError!, error: true),
    ]);
  }

  Widget _connectionButtons(Insta360State s) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: s.supported && !s.connected
                ? () => _connect(Insta360ConnectType.usb)
                : null,
            child: const Text('Connect USB'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: s.supported && !s.connected
                ? () => _connect(Insta360ConnectType.wifi)
                : null,
            child: const Text('Connect WiFi'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: s.connected ? () => _service.disconnect() : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Disconnect'),
          ),
        ),
      ],
    );
  }

  Widget _spikeCard(Insta360State s) {
    return _card([
      const Text('Agora test push',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      const Text('Pushes extracted frames into an Agora channel as an external video source.',
          style: TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 10),
      TextField(
        controller: _channelCtrl,
        enabled: !_spikeActive,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          labelText: 'Channel name',
          labelStyle: TextStyle(color: Colors.white54),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: (!s.connected || _spikeActive) ? null : _startSpike,
              child: const Text('Start spike'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: _spikeActive ? _stopSpike : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Stop'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _row('Spike', _spikeStatus),
      _row('Pushed frames', '$_pushedFrames'),
    ]);
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _row(String k, String v, {bool error = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                color: error ? Colors.redAccent : Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
