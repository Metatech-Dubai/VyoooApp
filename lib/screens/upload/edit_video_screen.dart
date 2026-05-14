import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../../core/mock/mock_music_data.dart';
import '../../core/navigation/app_route_observer.dart';
import '../../core/utils/reel_video_tone.dart';
import '../../core/utils/reel_video_trimmer.dart';
import '../../core/theme/app_spacing.dart';
import '../music/add_audio_screen.dart';
import 'upload_details_screen.dart';
import 'widgets/reel_brightness_sheet.dart';
import 'widgets/reel_trim_sheet.dart';

/// Edit video screen: title, close, Next >, video preview, tool row, timeline with scrubber.
class EditVideoScreen extends StatefulWidget {
  const EditVideoScreen({super.key, required this.asset});

  final AssetEntity asset;

  @override
  State<EditVideoScreen> createState() => _EditVideoScreenState();
}

class _EditVideoScreenState extends State<EditVideoScreen>
    with RouteAware, WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _muted = true;
  bool _isRouteVisible = true;
  bool _isAppForeground = true;
  bool _isRouteObserverSubscribed = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  MusicTrack? _selectedTrack;

  /// Original gallery file (used for the first trim only).
  File? _sourceVideoFile;

  /// Last FFmpeg export; uploaded on Next. Further trims use this as input.
  File? _trimmedVideoFile;
  Duration _trimStart = Duration.zero;
  Duration _trimEnd = Duration.zero;

  /// Last applied FFmpeg `eq` brightness (\([-1, 1]\)) for reopening the sheet.
  double _lastBrightnessEq = 0;

  static const Color _pink = Color(0xFFDE106B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVideo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isRouteObserverSubscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      appRouteObserver.subscribe(this, route);
      _isRouteObserverSubscribed = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
      _isRouteObserverSubscribed = false;
    }
    _audioPlayer.dispose();
    _controller?.removeListener(_listener);
    _controller?.dispose();
    final trimmed = _trimmedVideoFile;
    if (trimmed != null && _isReelExportTemp(trimmed) && trimmed.existsSync()) {
      try {
        trimmed.deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  bool _isReelExportTemp(File f) {
    final segments = f.uri.pathSegments;
    if (segments.isEmpty) return false;
    final name = segments.last;
    return name.startsWith('vy_reel_trim_') || name.startsWith('vy_reel_adj_');
  }

  @override
  void didPushNext() {
    if (!_isRouteVisible) return;
    setState(() => _isRouteVisible = false);
    _syncMediaPlayback();
  }

  @override
  void didPopNext() {
    if (_isRouteVisible) return;
    setState(() => _isRouteVisible = true);
    _syncMediaPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _isAppForeground) return;
    _isAppForeground = foreground;
    _syncMediaPlayback();
  }

  void _listener() {
    if (mounted) setState(() {});
  }

  Future<void> _initVideo() async {
    try {
      final file = await widget.asset.file;
      if (file == null || !mounted) return;
      _sourceVideoFile = file;
      _controller = VideoPlayerController.file(file);
      _controller!.setLooping(true);
      _controller!.setVolume(_muted ? 0 : 1);
      _controller!.addListener(_listener);
      await _controller!.initialize();
      if (mounted) {
        final d = _controller!.value.duration;
        setState(() {
          _isInitialized = true;
          _hasError = false;
          _trimStart = Duration.zero;
          _trimEnd = d;
        });
        _syncMediaPlayback();
      }
    } catch (e) {
      debugPrint('EditVideoScreen: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _hasError = true;
        });
      }
    }
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _controller?.setVolume(_muted ? 0 : 1);
    });
  }

  void _syncMediaPlayback() {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;
    final shouldPlayVideo = _isRouteVisible && _isAppForeground;
    if (shouldPlayVideo) {
      controller.play();
      if (_selectedTrack != null && !_audioPlaying) {
        _audioPlayer.play();
      }
    } else {
      controller.pause();
      if (_audioPlaying) {
        _audioPlayer.pause();
      }
    }
  }

  bool get _audioPlaying => _audioPlayer.playing;

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _openTrimSheet() {
    if (!_isInitialized || _controller == null || _sourceVideoFile == null) {
      return;
    }
    final total = _controller!.value.duration;
    if (total.inMilliseconds < 600) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ReelTrimSheet(
        totalDuration: total,
        initialStart: _trimStart,
        initialEnd: _trimEnd,
        onApply: _exportTrim,
      ),
    );
  }

  Future<void> _exportTrim(Duration start, Duration end) async {
    final src = _trimmedVideoFile ?? _sourceVideoFile;
    if (src == null || !mounted) return;

    final previous = _trimmedVideoFile;
    final out = await ReelVideoTrimmer.trimToMp4(
      input: src,
      start: start,
      end: end,
    );

    try {
      if (previous != null &&
          previous.path != out.path &&
          _isReelExportTemp(previous) &&
          await previous.exists()) {
        await previous.delete();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _trimmedVideoFile = out;
      _trimStart = start;
      _trimEnd = end;
      _lastBrightnessEq = 0;
    });
    await _reloadVideoFromFile(out);
  }

  void _openBrightnessSheet() {
    if (!_isInitialized || _controller == null || _sourceVideoFile == null) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ReelBrightnessSheet(
        initialEqBrightness: _lastBrightnessEq,
        onApply: _exportBrightness,
      ),
    );
  }

  Future<void> _exportBrightness(double eqBrightness) async {
    final src = _trimmedVideoFile ?? _sourceVideoFile;
    if (src == null || !mounted) return;

    final out = await ReelVideoTone.applyBrightness(
      input: src,
      brightness: eqBrightness,
    );

    if (out.path == src.path) {
      if (mounted) setState(() => _lastBrightnessEq = eqBrightness);
      return;
    }

    final previous = _trimmedVideoFile;
    try {
      if (previous != null &&
          previous.path != out.path &&
          _isReelExportTemp(previous) &&
          await previous.exists()) {
        await previous.delete();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _trimmedVideoFile = out;
      _lastBrightnessEq = eqBrightness;
    });
    await _reloadVideoFromFile(out);
  }

  Future<void> _reloadVideoFromFile(File file) async {
    _controller?.removeListener(_listener);
    await _controller?.dispose();
    if (!mounted) return;

    setState(() {
      _controller = null;
      _isInitialized = false;
      _hasError = false;
    });

    final c = VideoPlayerController.file(file)
      ..setLooping(true)
      ..setVolume(_muted ? 0 : 1)
      ..addListener(_listener);
    _controller = c;

    try {
      await c.initialize();
      if (!mounted) return;
      final d = c.value.duration;
      setState(() {
        _isInitialized = true;
        _hasError = false;
        _trimStart = Duration.zero;
        _trimEnd = d;
      });
      _syncMediaPlayback();
    } catch (e) {
      debugPrint('EditVideoScreen reload: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full screen video
          _buildVideoArea(),
          
          // 2. Translucent top/bottom gradients for readability
          _buildGradients(),

          // 3. Header controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                if (_selectedTrack != null) ...[
                  const SizedBox(height: 12),
                  _buildMusicBar(),
                ],
              ],
            ),
          ),

          // 4. Bottom controls (Tools + Timeline)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToolRow(),
                const SizedBox(height: 16),
                _buildTimeline(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradients() {
    return IgnorePointer(
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
              ),
            ),
          ),
          const Spacer(),
          Container(
            height: 240,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (ctx) => _ExitSheet(
                onContinue: () => Navigator.pop(ctx),
                onExit: () {
                  Navigator.pop(ctx); // close sheet
                  Navigator.pop(context); // close editor
                },
              ),
            );
          },
          child: const Icon(Icons.close, color: Colors.white, size: 28),
        ),
        const Spacer(),
        _headerActionPill(
          label: 'Trim',
          icon: Icons.content_cut_rounded,
          onTap: _openTrimSheet,
          isPink: false,
        ),
        const SizedBox(width: 8),
        _headerActionPill(
          label: 'Next',
          icon: Icons.arrow_forward_ios_rounded,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => UploadDetailsScreen(
                  asset: widget.asset,
                  videoFileOverride: _trimmedVideoFile,
                ),
              ),
            );
          },
          isPink: true,
        ),
      ],
    );
  }

  Widget _headerActionPill({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isPink,
  }) {
    final isNext = label == 'Next';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isNext
              ? Colors.white
              : (isPink ? _pink : Colors.black.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isNext ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Icon(icon, color: isNext ? Colors.black : Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoArea() {
    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isInitialized && _controller != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else if (_hasError)
            const Center(
              child: Text(
                'Could not load video',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildToolRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _toolIconButton(
            icon: Icons.music_note_rounded,
            onTap: () {
              _controller?.pause();
              Navigator.of(context)
                  .push<MusicTrack?>(MaterialPageRoute(
                    builder: (_) => AddAudioScreen(videoAsset: widget.asset),
                  ))
                  .then((track) async {
                if (!mounted) return;
                if (track != null) {
                  setState(() => _selectedTrack = track);
                  _controller?.setVolume(0);
                  setState(() => _muted = true);
                  try {
                    await _audioPlayer.setUrl(track.audioUrl);
                    await _audioPlayer.play();
                  } catch (_) {}
                }
                _controller?.play();
              });
            },
          ),
          _toolIconButton(
            icon: Icons.tune_rounded,
            onTap: _openBrightnessSheet,
          ),
          _toolIconButton(icon: Icons.content_cut_rounded, onTap: _openTrimSheet),
          _toolIconButton(
            icon: Icons.timer_outlined,
            onTap: () => _showEditorNotAvailable('Speed'),
          ),
          _toolIconButton(
            icon: Icons.delete_outline_rounded,
            onTap: _onDiscardTrimTap,
          ),
        ],
      ),
    );
  }

  void _showEditorNotAvailable(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name is not available in this version yet.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onDiscardTrimTap() {
    if (_trimmedVideoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Apply a trim or brightness change first if you want to discard it and go back to the original clip.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0020),
        title: const Text('Discard changes?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove edited video and show the original library clip again.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _discardTrimmedExport();
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Future<void> _discardTrimmedExport() async {
    final trimmed = _trimmedVideoFile;
    final source = _sourceVideoFile;
    if (trimmed == null || source == null || !mounted) return;
    try {
      if (_isReelExportTemp(trimmed) && await trimmed.exists()) {
        await trimmed.delete();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _trimmedVideoFile = null;
      _lastBrightnessEq = 0;
    });
    await _reloadVideoFromFile(source);
  }

  Widget _toolIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }

  Widget _buildMusicBar() {
    final t = _selectedTrack!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
      decoration: BoxDecoration(
        color: _pink.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _pink.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.music_note_rounded, color: _pink, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.title} • ${t.artist}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Preview only — the uploaded video still uses the clip\'s original audio.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              _audioPlayer.stop();
              setState(() => _selectedTrack = null);
              _controller?.setVolume(_muted ? 0 : 1);
            },
            child: const Icon(Icons.close, color: Colors.white70, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    if (!_isInitialized || _controller == null) {
      return const SizedBox(height: 50);
    }
    final pos = _controller!.value.position;
    final dur = _controller!.value.duration;
    final totalSec = dur.inMilliseconds > 0 ? dur.inMilliseconds / 1000 : 1.0;
    final progress = totalSec > 0 ? (pos.inMilliseconds / 1000 / totalSec).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                overlayColor: Colors.transparent,
                thumbColor: _pink,
                activeTrackColor: _pink,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: progress,
                onChanged: (v) {
                  final sec = v * dur.inMilliseconds / 1000;
                  _controller?.seekTo(Duration(milliseconds: (sec * 1000).round()));
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(dur),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleMute,
            child: Icon(
              _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Exit Sheet ────────────────────────────────────────────────────────────────

class _ExitSheet extends StatelessWidget {
  const _ExitSheet({required this.onContinue, required this.onExit});
  final VoidCallback onContinue;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E0A1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          const Text(
            'Are you sure you want to quit uploading?',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _sheetBtn(
            icon: Icons.edit_note_rounded,
            label: 'Continue Uploading',
            onTap: onContinue,
          ),
          const SizedBox(height: 16),
          _sheetBtn(
            icon: Icons.logout_rounded,
            label: 'Exit editing',
            isExit: true,
            onTap: onExit,
          ),
        ],
      ),
    );
  }

  Widget _sheetBtn({required IconData icon, required String label, bool isExit = false, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isExit ? Colors.red.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isExit ? Colors.redAccent : Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
