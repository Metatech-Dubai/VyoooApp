import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import 'auth_floating_circle_button.dart';

/// Bottom-left floating back control (find-account / forgot-password placement).
class AuthFloatingBackButton extends StatelessWidget {
  const AuthFloatingBackButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
  });

  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: AppSpacing.xl,
      bottom: AppSpacing.authFloatingNavBottom,
      child: AuthFloatingCircleButton.back(
        onPressed: onPressed,
        enabled: enabled,
      ),
    );
  }
}
