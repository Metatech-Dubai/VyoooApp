import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_padding.dart';
import '../theme/app_sizes.dart';
import '../theme/app_typography.dart';

/// Live stream comment field — Figma: 224×32, rx 8, white 10% + 5px blur, #EEEEEE text.
class LiveCommentInputField extends StatelessWidget {
  const LiveCommentInputField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  static final BorderRadius _radius = BorderRadius.circular(
    AppSizes.liveCommentInputRadius,
  );

  static InputDecoration _decoration() {
    return const InputDecoration(
      hintText: 'Comment..',
      hintStyle: AppTypography.liveCommentInput,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: AppPadding.liveCommentInputContent,
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: _radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.liveCommentInputGlassFill,
            borderRadius: _radius,
          ),
          child: SizedBox(
            height: AppSizes.liveCommentInputHeight,
            child: TextField(
              controller: controller,
              enabled: enabled,
              style: AppTypography.liveCommentInput,
              cursorColor: AppColors.liveCommentInputText,
              textInputAction: TextInputAction.send,
              onSubmitted: onSubmitted,
              decoration: _decoration(),
            ),
          ),
        ),
      ),
    );
  }
}
