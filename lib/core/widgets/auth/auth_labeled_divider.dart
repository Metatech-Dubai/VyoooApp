import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

class AuthLabeledDivider extends StatelessWidget {
  const AuthLabeledDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    final lineColor =
        isLight ? AppTheme.lightUnfocusedUnderline : White24.value;
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: lineColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.storyItem),
          child: Text(
            label,
            style: AppTypography.authDividerLabel.copyWith(
              color: isLight ? AppTheme.lightMutedBody : null,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: lineColor)),
      ],
    );
  }
}
