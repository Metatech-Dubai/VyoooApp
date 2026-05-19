import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import 'auth_floating_circle_button.dart';

/// Back (left) and forward (right) on one bottom row for auth/onboarding flows.
class AuthFloatingNavRow extends StatelessWidget {
  const AuthFloatingNavRow({
    super.key,
    required this.onBack,
    this.onForward,
    this.forwardEnabled = true,
    this.forwardLoading = false,
  });

  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final bool forwardEnabled;
  final bool forwardLoading;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: AppSpacing.xl,
      right: AppSpacing.xl,
      bottom: AppSpacing.authFloatingNavBottom,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AuthFloatingCircleButton.back(onPressed: onBack),
          AuthFloatingCircleButton.forward(
            onPressed: onForward,
            enabled: forwardEnabled && !forwardLoading,
            isLoading: forwardLoading,
          ),
        ],
      ),
    );
  }
}
