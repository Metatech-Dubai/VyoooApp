import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Centered dark pill shown on the home feed after a post upload completes.
class UploadPostSuccessToast extends StatelessWidget {
  const UploadPostSuccessToast({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.uploadPostSuccessToastBackground,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.uploadPostSuccessToast,
        ),
      ),
    );
  }
}
