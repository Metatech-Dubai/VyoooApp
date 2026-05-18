import 'package:flutter/material.dart';

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
                activeColor: AppTheme.primary,
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppTheme.primary;
                  }
                  return Colors.transparent;
                }),
                side: const BorderSide(color: AppTheme.primary),
                shape: const CircleBorder(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Remember me', style: AppTypography.authSmallBody),
          ],
        ),
        GestureDetector(
          onTap: onForgotPasswordTap,
          child: Text('Forgot Password?', style: AppTypography.authSmallBodyBold),
        ),
      ],
    );
  }
}
