import 'package:flutter/material.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_text_field_style.dart';
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
    this.onChanged,
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
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    final iconColor = isLight ? AppTheme.lightOnSurface : AppTheme.primary;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      onTap: onTap,
      onChanged: onChanged,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      keyboardAppearance: AppTextFieldStyle.keyboardAppearance(context),
      cursorColor: AppTextFieldStyle.cursorColor(context),
      style: AppTypography.input.copyWith(
        color: isLight ? AppTheme.lightOnSurface : AppTheme.defaultTextColor,
      ),
      decoration: AppTextFieldStyle.underlineDecoration(
        context,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: isLight
              ? AppTypography.inputHint.copyWith(color: AppTheme.lightHintText)
              : AppTypography.inputHint,
          prefixIcon: prefix ??
              (icon != null
                  ? Icon(icon, color: iconColor, size: AppSizes.fieldIcon)
                  : null),
          prefixIconConstraints: prefixIconConstraints,
          suffixIcon: suffixIcon,
          suffixIconConstraints: const BoxConstraints(
            minWidth: AppSizes.iconTapTarget,
            minHeight: AppSizes.iconTapTarget,
          ),
        ),
      ),
    );
  }
}
