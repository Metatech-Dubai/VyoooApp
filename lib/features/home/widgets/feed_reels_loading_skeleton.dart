import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// Full-viewport placeholder shown while the feed has no cached/network reels yet.
class FeedReelsLoadingSkeleton extends StatefulWidget {
  const FeedReelsLoadingSkeleton({super.key, this.borderRadius = BorderRadius.zero});

  final BorderRadius borderRadius;

  @override
  State<FeedReelsLoadingSkeleton> createState() => _FeedReelsLoadingSkeletonState();
}

class _FeedReelsLoadingSkeletonState extends State<FeedReelsLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_pulse.value);
          final base = Color.lerp(
            const Color(0xFF1A1A1A),
            const Color(0xFF2E2E2E),
            t,
          )!;
          return ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: base),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _shimmerBar(base, width: 120, height: 14),
                        SizedBox(height: AppSpacing.sm),
                        _shimmerBar(base, width: 200, height: 12),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.55 + (0.2 * t)),
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        'Loading your feed…',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _shimmerBar(Color base, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
