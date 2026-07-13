import 'package:flutter/material.dart';

import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_typography.dart';

abstract final class UploadVideoScrubberAssets {
  static const String muteIcon =
      'assets/vyooO_icons/Upload_Story_Live/mute_video.png';
}

/// Figma 386×22 video scrubber — seek track, duration, mute toggle.
class UploadVideoScrubberBar extends StatelessWidget {
  const UploadVideoScrubberBar({
    super.key,
    required this.progress,
    required this.durationLabel,
    required this.muted,
    required this.onSeek,
    required this.onMuteToggle,
  });

  final double progress;
  final String durationLabel;
  final bool muted;
  final ValueChanged<double> onSeek;
  final VoidCallback onMuteToggle;

  static const double _designWidth = AppSizes.uploadVideoScrubberBarWidth;
  static const double _designHeight = AppSizes.uploadVideoScrubberBarHeight;
  static const double _trackLeft = 4;
  static const double _trackWidth = 277;
  static const double _thumbRadius = 3.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = _designHeight;
        final scale = width / _designWidth;
        final trackLeft = _trackLeft * scale;
        final trackWidth = _trackWidth * scale;
        final thumbX = trackLeft + (trackWidth * progress.clamp(0.0, 1.0));

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned(
                left: trackLeft,
                top: (height - 3) / 2,
                width: trackWidth,
                height: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
              Positioned(
                left: trackLeft,
                top: (height - 3) / 2,
                width: trackWidth * progress.clamp(0.0, 1.0),
                height: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
              Positioned(
                left: thumbX - _thumbRadius,
                top: (height - _thumbRadius * 2) / 2,
                child: Container(
                  width: _thumbRadius * 2,
                  height: _thumbRadius * 2,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: trackLeft,
                top: 0,
                width: trackWidth,
                height: height,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) =>
                      _seekFromLocalX(details.localPosition.dx, trackWidth),
                  onTapDown: (details) =>
                      _seekFromLocalX(details.localPosition.dx, trackWidth),
                ),
              ),
              Positioned(
                right: 52 * scale,
                child: Text(
                  durationLabel,
                  style: AppTypography.uploadVideoScrubberDuration,
                ),
              ),
              Positioned(
                right: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onMuteToggle,
                  child: SizedBox(
                    width: 22 * scale,
                    height: height,
                    child: Center(
                      child: Image.asset(
                        UploadVideoScrubberAssets.muteIcon,
                        width: 18 * scale,
                        height: 18 * scale,
                        color: muted ? const Color(0xFFF0F0F0) : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _seekFromLocalX(double localX, double trackWidth) {
    if (trackWidth <= 0) return;
    onSeek((localX / trackWidth).clamp(0.0, 1.0));
  }
}
