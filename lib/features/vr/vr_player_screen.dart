import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_spacing.dart';

/// VR player for testing: plays a video fullscreen. Replace with real VR/streaming later.
class VrPlayerScreen extends StatefulWidget {
  const VrPlayerScreen({
    super.key,
    this.title,
    this.videoUrl,
  });

  final String? title;

  /// Video URL to play. If null, uses a default test URL.
  final String? videoUrl;

  /// Default test URLs for development. Replace with real VR streams later.
  static const List<String> testVideoUrls = [
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    'https://assets.mixkit.co/videos/24481/24481-720.mp4',
  ];

  @override
  State<VrPlayerScreen> createState() => _VrPlayerScreenState();
}

class _VrPlayerScreenState extends State<VrPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    final url = widget.videoUrl ??
        VrPlayerScreen.testVideoUrls[
            DateTime.now().millisecond % VrPlayerScreen.testVideoUrls.length];
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );
      _controller!.setLooping(true);
      _controller!.setVolume(1.0);
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        await _controller!.play();
      }
    } catch (e) {
      debugPrint('VrPlayerScreen: Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _hasError = true;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isInitialized && _controller != null)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (_hasError)
              _buildErrorState()
            else
              _buildLoadingState(),
            // Top bar with back and title
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  left: AppSpacing.xs,
                  right: AppSpacing.md,
                  bottom: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.white, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          widget.title ?? 'VR',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Tap to play/pause
            if (_isInitialized)
              GestureDetector(
                onTap: _togglePlayPause,
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _controller?.value.isPlaying == true ? 0.0 : 0.8,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _controller?.value.isPlaying == true
                          ? Icons.play_circle_filled
                          : Icons.pause_circle_filled,
                      color: Colors.white,
                      size: 72,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'Loading…',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 48),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Could not load video',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () {
                setState(() => _hasError = false);
                _initializePlayer();
              },
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
