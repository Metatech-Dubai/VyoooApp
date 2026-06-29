import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
    final iconColor = isLight ? AppTheme.lightOnSurface : AppTheme.primary;
    return IconButton(
      icon: Icon(
        obscured ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
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
