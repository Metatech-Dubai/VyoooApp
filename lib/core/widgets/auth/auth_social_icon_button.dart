import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';

class AuthSocialIconButton extends StatelessWidget {
  const AuthSocialIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.isLoading = false,
  });

  final FaIconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    final iconColor = isLight ? AppTheme.lightOnSurface : AppTheme.primary;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: SizedBox(
        width: AppSizes.socialIconContainer,
        height: AppSizes.socialIconContainer,
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: AppSizes.socialIcon,
                  height: AppSizes.socialIcon,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: iconColor,
                  ),
                )
              : FaIcon(icon, color: iconColor, size: AppSizes.socialIcon),
        ),
      ),
    );
  }
}
