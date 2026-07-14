import 'package:flutter/material.dart';

import '../../platform/app_system_ui.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import 'auth_floating_nav_visibility.dart';
import 'auth_pill_button.dart';

/// Back (left) and Continue (right) on one bottom row for auth/onboarding flows.
class AuthFloatingNavRow extends StatelessWidget {
  const AuthFloatingNavRow({
    super.key,
    required this.onBack,
    this.onForward,
    this.forwardEnabled = true,
    this.forwardLoading = false,
    this.forwardLabel = 'Continue',
    /// When false (default), the back control is hidden if [Navigator.canPop] is false
    /// (e.g. onboarding steps shown as [AuthWrapper] / [OnboardingGate] roots).
    this.alwaysShowBack = false,
  });

  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final bool forwardEnabled;
  final bool forwardLoading;
  final String forwardLabel;
  final bool alwaysShowBack;

  /// Trailing spacer / scroll padding so content clears floating auth chrome.
  static double scrollBottomClearance(BuildContext context) =>
      AppSpacing.authFloatingNavBottom +
      AppSizes.authPillButtonHeight +
      AppSpacing.md +
      AppSystemUi.bottomChromeInset(context);

  @override
  Widget build(BuildContext context) {
    final showBack = shouldShowAuthFloatingBack(
      context,
      hasBackHandler: onBack != null,
      alwaysShowBack: alwaysShowBack,
    );
    final showForward = onForward != null;

    return Positioned(
      left: AppSpacing.xl,
      right: AppSpacing.xl,
      bottom:
          AppSpacing.authFloatingNavBottom +
          AppSystemUi.bottomChromeInset(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBack) ...[
            AuthPillIconButton.back(onPressed: onBack),
            if (showForward) const SizedBox(width: AppSpacing.md),
          ],
          if (showForward)
            Expanded(
              child: AuthPillButton(
                label: forwardLabel,
                onPressed: onForward,
                enabled: forwardEnabled && !forwardLoading,
                isLoading: forwardLoading,
              ),
            ),
        ],
      ),
    );
  }
}
