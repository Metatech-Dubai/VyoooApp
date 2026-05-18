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
    return IconButton(
      icon: Icon(
        obscured ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
        color: AppTheme.primary,
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
