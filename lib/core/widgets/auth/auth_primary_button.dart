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
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.buttonBackground,
          foregroundColor: AppTheme.buttonTextColor,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
        ),
        child: isLoading
            ? const SizedBox(
                width: AppSizes.progressIndicator,
                height: AppSizes.progressIndicator,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(label, style: AppTypography.primaryButton),
      ),
    );
  }
}
