import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// Feed nav notification bell (Figma: #FFF @ 30% circle, background blur, no stroke).
class AppFeedNotificationButton extends StatelessWidget {
  const AppFeedNotificationButton({
    super.key,
    required this.onTap,
    this.badge,
  });

  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: AppSizes.feedNotificationTapTarget,
        height: AppSizes.feedNotificationTapTarget,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: AppSizes.feedNotificationCircle,
                  height: AppSizes.feedNotificationCircle,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: White30.value,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppTheme.primary,
                    size: AppSizes.feedNotificationIcon,
                  ),
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                right: 0,
                top: 0,
                child: badge!,
              ),
          ],
        ),
      ),
    );
  }
}
