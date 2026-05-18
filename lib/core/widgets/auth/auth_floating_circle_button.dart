import 'package:flutter/material.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';

/// Circular FAB-style control on auth screens (back, forward).
class AuthFloatingCircleButton extends StatelessWidget {
  const AuthFloatingCircleButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.enabled = true,
  });

  const AuthFloatingCircleButton.back({
    super.key,
    required this.onPressed,
    this.enabled = true,
  }) : icon = Icons.arrow_back;

  const AuthFloatingCircleButton.forward({
    super.key,
    required this.onPressed,
    this.enabled = true,
  }) : icon = Icons.arrow_forward;

  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onPressed != null;
    return Material(
      elevation: 2,
      shape: const CircleBorder(),
      color: active
          ? AppTheme.buttonBackground
          : Colors.white.withValues(alpha: 0.4),
      child: InkWell(
        onTap: active ? onPressed : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSizes.buttonHeight,
          height: AppSizes.buttonHeight,
          child: Icon(
            icon,
            color: active ? AppTheme.buttonTextColor : White50.value,
            size: AppSizes.fieldIcon + 6,
          ),
        ),
      ),
    );
  }
}
