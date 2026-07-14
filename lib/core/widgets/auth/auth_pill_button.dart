import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Figma auth/onboarding CTA — #1A1A1A pill, 48px tall, white label.
class AuthPillButton extends StatelessWidget {
  const AuthPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;
  final bool expand;

  static const Color _fillColor = AppColors.authCtaButtonFill;
  static const Color _labelColor = AppTheme.lightButtonText;

  bool get _canPress => enabled && !isLoading && onPressed != null;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: expand ? double.infinity : null,
      height: AppSizes.authPillButtonHeight,
      child: Material(
        color: _canPress
            ? _fillColor
            : _fillColor.withValues(alpha: 0.4),
        borderRadius: AppRadius.authPillButtonRadius,
        child: InkWell(
          onTap: _canPress ? onPressed : null,
          borderRadius: AppRadius.authPillButtonRadius,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: AppSizes.progressIndicator,
                    height: AppSizes.progressIndicator,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_labelColor),
                    ),
                  )
                : Text(
                    label,
                    style: AppTypography.primaryButton.copyWith(
                      color: _canPress
                          ? _labelColor
                          : _labelColor.withValues(alpha: 0.7),
                    ),
                  ),
          ),
        ),
      ),
    );

    if (!expand) return button;
    return button;
  }
}

/// Compact 48×48 auth/onboarding chrome control (back / forward icon).
class AuthPillIconButton extends StatelessWidget {
  const AuthPillIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.enabled = true,
    this.isLoading = false,
  });

  const AuthPillIconButton.back({
    super.key,
    required this.onPressed,
    this.enabled = true,
  })  : icon = Icons.arrow_back,
        isLoading = false;

  const AuthPillIconButton.forward({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.isLoading = false,
  }) : icon = Icons.arrow_forward;

  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;

  static const Color _fillColor = AppColors.authCtaButtonFill;
  static const Color _iconColor = AppTheme.lightButtonText;

  bool get _canPress => enabled && onPressed != null && !isLoading;
  bool get _showActiveStyle => _canPress || isLoading;

  @override
  Widget build(BuildContext context) {
    if (onPressed == null && !isLoading) {
      return const SizedBox.shrink();
    }

    final fill = _showActiveStyle
        ? _fillColor
        : _fillColor.withValues(alpha: 0.4);
    final iconColor = _showActiveStyle
        ? _iconColor
        : _iconColor.withValues(alpha: 0.7);

    return Material(
      color: fill,
      borderRadius: AppRadius.authPillButtonRadius,
      child: InkWell(
        onTap: _canPress ? onPressed : null,
        borderRadius: AppRadius.authPillButtonRadius,
        child: SizedBox(
          width: AppSizes.authPillButtonHeight,
          height: AppSizes.authPillButtonHeight,
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: AppSizes.progressIndicator,
                    height: AppSizes.progressIndicator,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  ),
                )
              : Icon(
                  icon,
                  color: iconColor,
                  size: AppSizes.fieldIcon + 6,
                ),
        ),
      ),
    );
  }
}
