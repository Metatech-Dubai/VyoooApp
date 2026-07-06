import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/auth_assets.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

class AuthLabeledDivider extends StatelessWidget {
  const AuthLabeledDivider({
    super.key,
    required this.label,
    this.centerAsset,
  });

  final String label;

  /// Optional Figma vector label (e.g. register "Or sign up with").
  final String? centerAsset;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    if (isLight) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(child: _AuthDividerLine()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.storyItem),
            child: centerAsset != null
                ? SvgPicture.asset(
                    centerAsset!,
                    height: AppSizes.authDividerLabelHeight,
                  )
                : Text(
                    label,
                    style: AppTypography.authDividerLabel.copyWith(
                      color: AppTheme.lightOnSurface.withValues(alpha: 0.9),
                    ),
                  ),
          ),
          const Expanded(
            child: _AuthDividerLine(flipHorizontally: true),
          ),
        ],
      );
    }

    final lineColor = White24.value;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: _FadeLine(color: lineColor, fadeFromStart: true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.storyItem),
          child: Text(label, style: AppTypography.authDividerLabel),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: _FadeLine(color: lineColor, fadeFromStart: false),
          ),
        ),
      ],
    );
  }
}

class _AuthDividerLine extends StatelessWidget {
  const _AuthDividerLine({this.flipHorizontally = false});

  final bool flipHorizontally;

  @override
  Widget build(BuildContext context) {
    final line = Transform.translate(
      offset: const Offset(0, AppSizes.authDividerLineStrokeOffsetY),
      child: SvgPicture.asset(
        AuthAssets.dividerLine,
        height: AppSizes.authDividerLineHeight,
        width: double.infinity,
        fit: BoxFit.fitWidth,
      ),
    );
    return SizedBox(
      height: AppSizes.authDividerLabelHeight,
      child: Center(
        child: flipHorizontally ? Transform.flip(flipX: true, child: line) : line,
      ),
    );
  }
}

/// Horizontal rule that fades toward the outer edge (dark auth divider).
class _FadeLine extends StatelessWidget {
  const _FadeLine({required this.color, required this.fadeFromStart});

  final Color color;
  final bool fadeFromStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: fadeFromStart ? Alignment.centerLeft : Alignment.centerRight,
          end: fadeFromStart ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            color.withValues(alpha: 0),
            color,
          ],
        ),
      ),
    );
  }
}
