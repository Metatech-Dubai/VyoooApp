import 'package:flutter/material.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'auth_underline_text_field.dart';

/// Phone number field with country flag / dial-code picker prefix.
class AuthPhoneField extends StatelessWidget {
  const AuthPhoneField({
    super.key,
    required this.controller,
    required this.countryFlag,
    required this.countryDialCode,
    required this.onCountryTap,
    this.hint = 'Phone Number',
    this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final String countryFlag;
  final String countryDialCode;
  final VoidCallback onCountryTap;
  final String hint;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    final iconColor = isLight ? AppTheme.lightOnSurface : AppTheme.primary;
    return AuthUnderlineTextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      hint: hint,
      keyboardType: TextInputType.phone,
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      prefix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: AppSpacing.storyItem),
          Icon(
            Icons.phone_outlined,
            color: iconColor,
            size: AppSizes.fieldIcon,
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCountryTap,
            child: Text(
              '$countryFlag +$countryDialCode',
              style: AppTypography.authSmallBodyBold.copyWith(
                color: isLight ? AppTheme.lightOnSurface : AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}
