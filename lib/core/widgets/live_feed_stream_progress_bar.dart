import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';
import '../theme/app_sizes.dart';

/// Figma live stream progress — 402×3 full-bleed bar (display only; parent handles scrub).
class LiveFeedStreamProgressBar extends StatelessWidget {
  const LiveFeedStreamProgressBar({
    super.key,
    required this.progress,
    this.showScrubThumb = false,
  });

  /// Normalized position within the live session (0 = start, 1 = live edge).
  final double progress;

  /// When true, renders the pink scrub thumb at [progress].
  final bool showScrubThumb;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fillWidth = width * clamped;
        final thumbSize = AppSizes.liveFeedSeekThumbSize;
        final thumbCenterX = (width * clamped).clamp(
          thumbSize / 2,
          width - thumbSize / 2,
        );

        return SizedBox(
          height: AppSizes.liveFeedStreamProgressHeight,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  AppSizes.liveFeedStreamProgressRadius,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors.white.withValues(alpha: 0.34),
                    ),
                    if (fillWidth > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: fillWidth,
                          decoration: const BoxDecoration(
                            gradient: AppGradients.liveFeedStreamProgressFill,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (showScrubThumb)
                Positioned(
                  left: thumbCenterX - thumbSize / 2,
                  top: (AppSizes.liveFeedStreamProgressHeight - thumbSize) / 2,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppGradients.liveFeedStreamProgressFill,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
