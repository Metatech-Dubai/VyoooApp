import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/auth_assets.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';

class AuthPasswordVisibilityButton extends StatelessWidget {
  const AuthPasswordVisibilityButton({
    super.key,
    required this.obscured,
    required this.onToggle,
  });

  final bool obscured;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    if (isLight) {
      return IconButton(
        onPressed: onToggle,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppSizes.iconTapTarget,
            AppSizes.iconTapTarget,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: SvgPicture.asset(
          AuthAssets.passwordVisibilityIcon,
          width: AppSizes.authPasswordVisibilityIconWidth,
          height: AppSizes.authPasswordVisibilityIconHeight,
          colorFilter: ColorFilter.mode(
            AppTheme.lightOnSurface.withValues(alpha: obscured ? 1 : 0.45),
            BlendMode.srcIn,
          ),
        ),
      );
    }

    final iconColor = AppTheme.primary;
    return IconButton(
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: iconColor,
        size: AppSizes.fieldIcon,
      ),
      onPressed: onToggle,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      style: IconButton.styleFrom(
        minimumSize: const Size(
          AppSizes.iconTapTarget,
          AppSizes.iconTapTarget,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
