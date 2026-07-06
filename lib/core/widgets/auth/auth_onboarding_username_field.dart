import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Figma onboarding username pill — floating label, value, optional clear / status.
class AuthOnboardingUsernameField extends StatelessWidget {
  const AuthOnboardingUsernameField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.isChecking = false,
    this.showErrorBorder = false,
    this.showSuccessBorder = false,
    this.showClearButton = false,
    this.showSuccessIcon = false,
    this.onClear,
    this.inputFormatters,
    this.borderAnimationDuration = const Duration(milliseconds: 200),
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isChecking;
  final bool showErrorBorder;
  final bool showSuccessBorder;
  final bool showClearButton;
  final bool showSuccessIcon;
  final VoidCallback? onClear;
  final List<TextInputFormatter>? inputFormatters;
  final Duration borderAnimationDuration;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: ListenableBuilder(
        listenable: Listenable.merge([controller, focusNode]),
        builder: (context, _) {
          final hasText = controller.text.isNotEmpty;
          final showInsetLabel = focusNode.hasFocus || hasText;
          final showBorder = showErrorBorder || showSuccessBorder;
          final borderColor = showErrorBorder
              ? AppColors.onboardingProgressFill
              : showSuccessBorder
              ? Colors.green
              : null;

          return GestureDetector(
            onTap: () => focusNode.requestFocus(),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: borderAnimationDuration,
              curve: Curves.easeInOut,
              height: AppSizes.onboardingUsernameFieldHeight,
              decoration: BoxDecoration(
                color: AppTheme.onboardingUsernameFieldFill,
                borderRadius: AppRadius.pillRadius,
                border: borderColor != null
                    ? Border.all(color: borderColor, width: 1.5)
                    : null,
                boxShadow: showBorder
                    ? null
                    : AppTheme.onboardingUsernameFieldShadow,
              ),
              padding: const EdgeInsets.only(
                left: AppSpacing.onboardingUsernameFieldHorizontal,
                right: AppSpacing.onboardingUsernameFieldHorizontal,
                top: AppSpacing.onboardingUsernameFieldValueTop,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _buildFieldContent(context, showInsetLabel)),
                  if (isChecking)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.authBrandBurgundy,
                        ),
                      ),
                    )
                  else if (showClearButton)
                    _ClearButton(onPressed: onClear)
                  else if (showSuccessIcon)
                    const Icon(
                      Icons.check,
                      color: Colors.green,
                      size: AppSizes.fieldIcon,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFieldContent(BuildContext context, bool showInsetLabel) {
    if (showInsetLabel) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Username',
            style: AppTypography.onboardingUsernameFieldLabel,
          ),
          const SizedBox(height: AppSpacing.onboardingUsernameFieldLabelGap),
          _usernameTextField(context, showInsetLabel: true),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.onboardingUsernameFieldEmptyTop),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _usernameTextField(context, showInsetLabel: false),
      ),
    );
  }

  Widget _usernameTextField(
    BuildContext context, {
    required bool showInsetLabel,
  }) {
    return DefaultTextStyle(
      style: AppTypography.onboardingUsernameFieldValue,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardAppearance: Brightness.light,
        cursorColor: AppColors.authBrandBurgundy,
        style: AppTypography.onboardingUsernameFieldValue,
        decoration: InputDecoration(
          hintText: showInsetLabel ? null : 'Username',
          hintStyle: AppTypography.onboardingUsernameFieldLabel,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
          isCollapsed: true,
        ),
        inputFormatters: inputFormatters,
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        child: SvgPicture.asset(
          'assets/vyooO_icons/Onboarding/username_field_clear.svg',
          width: AppSizes.fieldIcon,
          height: AppSizes.fieldIcon,
        ),
      ),
    );
  }
}
