import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

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
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = AppTheme.isLight(context);
    final canPress = enabled && !isLoading && onPressed != null;
    final fillColor = backgroundColor ??
        (isLight ? AppTheme.lightButtonBackground : AppTheme.buttonBackground);
    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeight,
      child: ElevatedButton(
        onPressed: canPress ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: fillColor,
          foregroundColor: isLight
              ? AppTheme.lightButtonText
              : AppTheme.buttonTextColor,
          disabledBackgroundColor: fillColor.withValues(alpha: 0.4),
          disabledForegroundColor: isLight
              ? AppTheme.lightButtonText.withValues(alpha: 0.7)
              : AppTheme.secondaryTextColor,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
        ),
        child: isLoading
            ? SizedBox(
                width: AppSizes.progressIndicator,
                height: AppSizes.progressIndicator,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isLight
                        ? AppTheme.lightButtonText
                        : AppTheme.buttonTextColor,
                  ),
                ),
              )
            : Text(
                label,
                style: AppTypography.primaryButton.copyWith(
                  color: isLight
                      ? AppTheme.lightButtonText
                      : theme.elevatedButtonTheme.style?.foregroundColor
                              ?.resolve({}) ??
                          AppTheme.buttonTextColor,
                ),
              ),
      ),
    );
  }
}
