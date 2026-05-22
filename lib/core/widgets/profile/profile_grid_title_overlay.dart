import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Bottom label on a profile grid thumbnail.
class ProfileGridTitleOverlay extends StatelessWidget {
  const ProfileGridTitleOverlay({
    super.key,
    required this.title,
    this.isHero = false,
    this.reservePlayIcon = false,
  });

  final String title;
  final bool isHero;
  final bool reservePlayIcon;

  @override
  Widget build(BuildContext context) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: reservePlayIcon ? 26 : AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              trimmed,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: isHero
                  ? AppTypography.profileGridTitleHero
                  : AppTypography.profileGridTitle,
            ),
          ),
        ),
      ),
    );
  }
}
