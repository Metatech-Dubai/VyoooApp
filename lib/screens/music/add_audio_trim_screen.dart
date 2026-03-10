import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../../core/mock/mock_music_data.dart';
import '../../core/theme/app_spacing.dart';

/// After selecting a track: full-screen video background, top X + Next >, bottom sheet with
/// Cancel/Done, track info, and waveform with pink trim segment and handles.
class AddAudioTrimScreen extends StatefulWidget {
  const AddAudioTrimScreen({
    super.key,
    required this.track,
    required this.videoAsset,
  });

  final MusicTrack track;
  final AssetEntity videoAsset;

  @override
  State<AddAudioTrimScreen> createState() => _AddAudioTrimScreenState();
}

class _AddAudioTrimScreenState extends State<AddAudioTrimScreen> {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  double _trimStart = 0.25;
  double _trimEnd = 0.75;

  static const Color _pink = Color(0xFFDE106B);
  static final List<double> _waveformHeights = List.generate(120, (_) => 0.2 + math.Random().nextDouble() * 0.8);

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    try {
      final file = await widget.videoAsset.file;
      if (file == null || !mounted) return;
      _controller = VideoPlayerController.file(file);
      _controller!.setLooping(true);
      _controller!.setVolume(0);
      await _controller!.initialize();
      if (mounted) {
        setState(() => _videoReady = true);
        await _controller!.play();
      }
    } catch (_) {
      if (mounted) setState(() => _videoReady = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoBackground(),
          _buildTopBar(context),
          _buildBottomSheet(context),
        ],
      ),
    );
  }

  Widget _buildVideoBackground() {
    if (!_videoReady || _controller == null) {
      return Container(color: Colors.black);
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Text(
              'add audio',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 26),
              style: IconButton.styleFrom(backgroundColor: Colors.black26),
            ),
            const SizedBox(width: AppSpacing.sm),
            Material(
              color: _pink,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Audio added'), behavior: SnackBarBehavior.floating),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
                  child: Text('Next >', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.42,
      minChildSize: 0.28,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1A0A1F),
                const Color(0xFF2D1525),
                const Color(0xFF1A0A1F),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              _buildTrackInfo(),
              const SizedBox(height: AppSpacing.md),
              _buildWaveform(context),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackInfo() {
    final t = widget.track;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(t.albumArtUrl, width: 72, height: 72, fit: BoxFit.cover),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  t.artist,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    _WaveformPainter(
                      heights: _waveformHeights,
                      trimStart: _trimStart,
                      trimEnd: _trimEnd,
                      width: constraints.maxWidth,
                    ),
                    Positioned(
                      left: _trimStart * constraints.maxWidth - 1,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (d) {
                          setState(() {
                            final dx = d.delta.dx / constraints.maxWidth;
                            _trimStart = (_trimStart + dx).clamp(0.0, _trimEnd - 0.05);
                          });
                        },
                        child: Container(width: 2, color: Colors.white),
                      ),
                    ),
                    Positioned(
                      left: _trimEnd * constraints.maxWidth - 1,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (d) {
                          setState(() {
                            final dx = d.delta.dx / constraints.maxWidth;
                            _trimEnd = (_trimEnd + dx).clamp(_trimStart + 0.05, 1.0);
                          });
                        },
                        child: Container(width: 2, color: Colors.white),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends StatelessWidget {
  const _WaveformPainter({
    required this.heights,
    required this.trimStart,
    required this.trimEnd,
    required this.width,
  });

  final List<double> heights;
  final double trimStart;
  final double trimEnd;
  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, 48),
      painter: _WaveformPainterDelegate(
        heights: heights,
        trimStart: trimStart,
        trimEnd: trimEnd,
      ),
    );
  }
}

class _WaveformPainterDelegate extends CustomPainter {
  _WaveformPainterDelegate({
    required this.heights,
    required this.trimStart,
    required this.trimEnd,
  });

  final List<double> heights;
  final double trimStart;
  final double trimEnd;

  static const Color _pink = Color(0xFFDE106B);

  @override
  void paint(Canvas canvas, Size size) {
    final n = heights.length;
    final barWidth = size.width / n;
    final centerY = size.height / 2;

    for (var i = 0; i < n; i++) {
      final x = i * barWidth;
      final t = (i + 0.5) / n;
      final inRange = t >= trimStart && t <= trimEnd;
      final h = (heights[i] * size.height * 0.4).clamp(2.0, size.height * 0.45);
      final paint = Paint()
        ..color = inRange ? _pink : Colors.white.withValues(alpha: 0.25);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x + barWidth / 2, centerY), width: (barWidth * 0.6).clamp(1, 4), height: h),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainterDelegate old) =>
      old.trimStart != trimStart || old.trimEnd != trimEnd;
}
