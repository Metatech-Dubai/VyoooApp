import 'package:flutter/material.dart';

import '../../core/theme/app_light_surface.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/settings/settings_inner_app_bar.dart';

/// Placeholder while creator revenue and payouts are not yet available.
class RevenueComingSoonView extends StatelessWidget {
  const RevenueComingSoonView({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppLightSurface.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showAppBar) const SettingsInnerAppBar(title: 'Revenue'),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppLightSurface.cardFill,
                          border: Border.all(
                            color: AppLightSurface.border,
                          ),
                        ),
                        child: const Icon(
                          Icons.payments_rounded,
                          size: 44,
                          color: AppLightSurface.icon,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Coming Soon',
                        textAlign: TextAlign.center,
                        style: AppTypography.onboardingSectionTitle.copyWith(
                          color: AppLightSurface.primaryText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Earnings, payouts, and revenue insights are on the way.\nStay tuned!',
                        textAlign: TextAlign.center,
                        style: AppTypography.onboardingPrivacyBody.copyWith(
                          color: AppLightSurface.secondaryText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppLightSurface.cardFill,
                          borderRadius: AppRadius.pillRadius,
                          border: Border.all(
                            color: AppLightSurface.border,
                          ),
                        ),
                        child: Text(
                          'Revenue',
                          style: AppTypography.caption.copyWith(
                            color: AppLightSurface.mutedText,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
