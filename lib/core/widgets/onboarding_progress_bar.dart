import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_theme.dart';

/// Reusable onboarding progress bar. Same style across profile, interests, etc.
/// [progress] should be between 0.0 and 1.0.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    final trackColor = isLight
        ? AppTheme.lightUnfocusedUnderline
        : Colors.white.withValues(alpha: 0.6);
    final fillColor =
        isLight ? AppColors.authBrandBurgundy : AppColors.brandPink;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;
        final fillWidth = fullWidth * progress.clamp(0.0, 1.0);
        return ClipRRect(
          borderRadius: AppRadius.inputRadius,
          child: SizedBox(
            height: 3,
            width: double.infinity,
            child: Stack(
              children: [
                Container(
                  width: fullWidth,
                  height: 3,
                  color: trackColor,
                ),
                SizedBox(
                  width: fillWidth,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(10),
                        right: Radius.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
