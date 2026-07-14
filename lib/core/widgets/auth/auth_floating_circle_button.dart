import 'package:flutter/material.dart';

import 'auth_pill_button.dart';

/// Circular FAB-style control on auth screens (back, forward).
class AuthFloatingCircleButton extends StatelessWidget {
  const AuthFloatingCircleButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.enabled = true,
    this.isLoading = false,
    this.backgroundColor,
  });

  const AuthFloatingCircleButton.back({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.backgroundColor,
  })  : icon = Icons.arrow_back,
        isLoading = false;

  const AuthFloatingCircleButton.forward({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.isLoading = false,
    this.backgroundColor,
  }) : icon = Icons.arrow_forward;

  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;

  /// Kept for call-site compatibility; Figma chrome uses [AppColors.authCtaButtonFill].
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AuthPillIconButton(
      icon: icon,
      onPressed: onPressed,
      enabled: enabled,
      isLoading: isLoading,
    );
  }
}
