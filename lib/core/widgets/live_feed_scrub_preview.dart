import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_typography.dart';

/// Floating thumbnail + timestamp shown above the live progress scrub thumb.
class LiveFeedScrubPreview extends StatelessWidget {
  const LiveFeedScrubPreview({
    super.key,
    required this.timeLabel,
    this.imageBytes,
    this.fallbackImageUrl,
  });

  final String timeLabel;
  final Uint8List? imageBytes;
  final String? fallbackImageUrl;

  @override
  Widget build(BuildContext context) {
    final width = AppSizes.liveFeedScaleW(
      context,
      AppSizes.liveFeedSeekPreviewWidth,
    );
    final height = AppSizes.liveFeedScaleH(
      context,
      AppSizes.liveFeedSeekPreviewHeight,
    );
    final radius = AppSizes.liveFeedScaleW(
      context,
      AppSizes.liveFeedSeekPreviewRadius,
    );

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImage(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  timeLabel,
                  style: AppTypography.liveFeedSeekPreviewTime,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return Image.memory(
        imageBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, error, stackTrace) => _fallbackImage(),
      );
    }
    return _fallbackImage();
  }

  Widget _fallbackImage() {
    final url = fallbackImageUrl?.trim();
    if (url != null && url.isNotEmpty && Uri.tryParse(url)?.isAbsolute == true) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return ColoredBox(
      color: const Color(0xFF1A0A24),
      child: Icon(
        Icons.play_circle_outline_rounded,
        color: Colors.white.withValues(alpha: 0.35),
        size: 32,
      ),
    );
  }
}
