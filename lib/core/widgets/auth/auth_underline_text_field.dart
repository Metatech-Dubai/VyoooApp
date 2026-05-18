import 'package:flutter/material.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Underline-style field used on auth screens (sign-in, register).
class AuthUnderlineTextField extends StatelessWidget {
  const AuthUnderlineTextField({
    super.key,
    this.controller,
    this.focusNode,
    required this.hint,
    this.icon,
    this.prefix,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIconConstraints,
    this.onTap,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final IconData? icon;
  final Widget? prefix;
  final BoxConstraints? prefixIconConstraints;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Widget? suffixIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      onTap: onTap,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: AppTypography.input,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefix ??
            (icon != null
                ? Icon(icon, color: AppTheme.primary, size: AppSizes.fieldIcon)
                : null),
        prefixIconConstraints: prefixIconConstraints,
        suffixIcon: suffixIcon,
        suffixIconConstraints: const BoxConstraints(
          minWidth: AppSizes.iconTapTarget,
          minHeight: AppSizes.iconTapTarget,
        ),
      ),
    );
  }
}
