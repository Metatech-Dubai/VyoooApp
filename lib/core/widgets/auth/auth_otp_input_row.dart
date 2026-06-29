import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_text_field_style.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Row of single-digit OTP boxes (Figma verify-code style).
class AuthOtpInputRow extends StatelessWidget {
  const AuthOtpInputRow({
    super.key,
    required this.length,
    required this.controllers,
    required this.focusNodes,
    this.onChanged,
    this.boxSize,
  });

  final int length;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final VoidCallback? onChanged;
  final double? boxSize;

  @override
  Widget build(BuildContext context) {
    final resolvedBoxSize = boxSize ?? AppSizes.authOtpBoxSize;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        length,
        (index) => _buildOtpBox(context, index, resolvedBoxSize),
      ),
    );
  }

  Widget _buildOtpBox(BuildContext context, int index, double size) {
    final isLight = AppTheme.isLight(context);
    return ListenableBuilder(
      listenable: focusNodes[index],
      builder: (_, _) {
        final hasFocus = focusNodes[index].hasFocus;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isLight
                ? AppTheme.lightOtpBoxFill
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: AppRadius.inputRadius,
            border: hasFocus
                ? Border.all(
                    color: isLight
                        ? AppColors.authBrandBurgundy
                        : Colors.white.withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : Border.all(
                    color: isLight
                        ? AppTheme.lightUnfocusedUnderline
                        : Colors.transparent,
                    width: 1,
                  ),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: controllers[index],
            focusNode: focusNodes[index],
            maxLength: 1,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            keyboardAppearance: AppTextFieldStyle.keyboardAppearance(context),
            cursorColor: AppTextFieldStyle.cursorColor(context),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onTap: () {
              controllers[index].selection = TextSelection(
                baseOffset: 0,
                extentOffset: controllers[index].text.length,
              );
            },
            onChanged: (value) {
              if (value.isNotEmpty && index < length - 1) {
                focusNodes[index + 1].requestFocus();
              } else if (value.isNotEmpty && index == length - 1) {
                FocusScope.of(context).unfocus();
              }
              onChanged?.call();
            },
            style: AppTypography.authOtpDigit.copyWith(
              color: isLight ? AppTheme.lightOnSurface : AppTheme.primary,
            ),
            decoration: InputDecoration(
              hintText: '-',
              hintStyle: AppTypography.authOtpDigit.copyWith(
                color: isLight
                    ? AppTheme.lightHintText
                    : AppTheme.primary.withValues(alpha: 0.5),
              ),
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );
      },
    );
  }
}
