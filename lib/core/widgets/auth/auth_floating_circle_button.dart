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
    this.isLoading = false,
  });

  const AuthFloatingCircleButton.back({
    super.key,
    required this.onPressed,
    this.enabled = true,
  }) : icon = Icons.arrow_back,
       isLoading = false;

  const AuthFloatingCircleButton.forward({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.isLoading = false,
  }) : icon = Icons.arrow_forward;

  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (onPressed == null && !isLoading) {
      return const SizedBox.shrink();
    }
    final canTap = enabled && onPressed != null && !isLoading;
    final showActiveStyle = canTap || isLoading;
    return Material(
      elevation: 2,
      shape: const CircleBorder(),
      color: showActiveStyle
          ? AppTheme.buttonBackground
          : Colors.white.withValues(alpha: 0.4),
      child: InkWell(
        onTap: canTap ? onPressed : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSizes.buttonHeight,
          height: AppSizes.buttonHeight,
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: AppSizes.progressIndicator,
                    height: AppSizes.progressIndicator,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.buttonTextColor,
                      ),
                    ),
                  ),
                )
              : Icon(
                  icon,
                  color: showActiveStyle
                      ? AppTheme.buttonTextColor
                      : White50.value,
                  size: AppSizes.fieldIcon + 6,
                ),
        ),
      ),
    );
  }
}
