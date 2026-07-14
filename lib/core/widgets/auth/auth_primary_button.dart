import 'package:flutter/material.dart';

import 'auth_pill_button.dart';

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.backgroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;

  /// Kept for call-site compatibility; Figma CTA uses [AppColors.authCtaButtonFill].
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AuthPillButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      enabled: enabled,
    );
  }
}
