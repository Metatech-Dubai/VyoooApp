import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/app_colors.dart';
import '../../constants/auth_assets.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Remember-me checkbox and forgot-password link on sign-in.
class AuthRememberForgotRow extends StatelessWidget {
  const AuthRememberForgotRow({
    super.key,
    required this.rememberMe,
    required this.onRememberMeChanged,
    required this.onForgotPasswordTap,
  });

  final bool rememberMe;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onForgotPasswordTap;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    final accentColor =
        isLight ? AppColors.authBrandBurgundy : AppTheme.primary;
    final labelColor =
        isLight ? AppTheme.lightOnSurface : AppTheme.defaultTextColor;
    final actionColor = isLight ? AppTheme.lightOnSurface : AppTheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: AppSpacing.xl,
              height: AppSpacing.xl,
              child: Checkbox(
                value: rememberMe,
                onChanged: (v) => onRememberMeChanged(v ?? false),
                activeColor: accentColor,
                checkColor: isLight ? Colors.white : AppTheme.buttonTextColor,
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return accentColor;
                  }
                  return Colors.transparent;
                }),
                side: BorderSide(
                  color: isLight
                      ? AppTheme.lightUnfocusedUnderline
                      : AppTheme.primary,
                ),
                shape: const CircleBorder(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (isLight)
              SvgPicture.asset(
                AuthAssets.rememberMe,
                height: AppSizes.authRememberMeLabelHeight,
              )
            else
              Text(
                'Remember me',
                style: AppTypography.authSmallBody.copyWith(color: labelColor),
              ),
          ],
        ),
        GestureDetector(
          onTap: onForgotPasswordTap,
          behavior: HitTestBehavior.opaque,
          child: isLight
              ? SvgPicture.asset(
                  AuthAssets.forgotPassword,
                  height: AppSizes.authForgotPasswordLabelHeight,
                )
              : Text(
                  'Forgot Password?',
                  style: AppTypography.authSmallBodyBold.copyWith(
                    color: actionColor,
                    decoration: TextDecoration.underline,
                    decorationColor: actionColor,
                  ),
                ),
        ),
      ],
    );
  }
}
