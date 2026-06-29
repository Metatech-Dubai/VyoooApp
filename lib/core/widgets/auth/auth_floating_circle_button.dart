import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
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
    final isLight = AppTheme.isLight(context);
    final canTap = enabled && onPressed != null && !isLoading;
    final showActiveStyle = canTap || isLoading;

    final activeColor = isLight
        ? AppColors.authBrandBurgundy
        : AppTheme.buttonBackground;
    final activeIconColor =
        isLight ? AppTheme.lightButtonText : AppTheme.buttonTextColor;
    final disabledColor = isLight
        ? AppTheme.lightOtpBoxFill
        : Colors.white.withValues(alpha: 0.4);
    final disabledIconColor =
        isLight ? AppTheme.lightSecondaryText : White50.value;

    return Material(
      elevation: isLight ? 0 : 2,
      shape: const CircleBorder(),
      color: showActiveStyle ? activeColor : disabledColor,
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(activeIconColor),
                    ),
                  ),
                )
              : Icon(
                  icon,
                  color: showActiveStyle ? activeIconColor : disabledIconColor,
                  size: AppSizes.fieldIcon + 6,
                ),
        ),
      ),
    );
  }
}
