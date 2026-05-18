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
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: SizedBox(
        width: AppSizes.socialIconContainer,
        height: AppSizes.socialIconContainer,
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: AppSizes.socialIcon,
                  height: AppSizes.socialIcon,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                )
              : FaIcon(icon, color: AppTheme.primary, size: AppSizes.socialIcon),
        ),
      ),
    );
  }
}
