import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../vyooo_brand_logo.dart';

/// Logo + headline block for auth flows.
class AuthScreenHeader extends StatelessWidget {
  const AuthScreenHeader({
    super.key,
    required this.title,
    this.titleWidget,
    this.subtitle,
    this.belowSubtitle = const [],
    this.centerAlign = false,
    this.titleTextAlign,
    this.subtitleTextAlign,
    this.showLogo = true,
  });

  final String title;

  /// Optional vector/custom headline (e.g. register "Create an Account" SVG).
  final Widget? titleWidget;

  final String? subtitle;
  final List<Widget> belowSubtitle;

  /// Centers logo when true.
  final bool centerAlign;

  /// Left/right/center for the headline (e.g. left with centered logo).
  final TextAlign? titleTextAlign;

  /// Defaults to [titleTextAlign] when null.
  final TextAlign? subtitleTextAlign;

  /// When false, only the headline/subtitle block is shown (logo pinned elsewhere).
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final columnAlign =
        centerAlign ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final defaultTextAlign = centerAlign ? TextAlign.center : TextAlign.start;
    final titleAlign = titleTextAlign ?? defaultTextAlign;
    final subtitleAlign =
        subtitleTextAlign ?? titleTextAlign ?? defaultTextAlign;

    return Column(
      crossAxisAlignment: columnAlign,
      children: [
        if (showLogo) ...[
          const VyoooBrandLogo.auth(),
          const SizedBox(height: AppSpacing.authLogoToHeadline),
        ],
        SizedBox(
          width: double.infinity,
          child: titleWidget ??
              Text(
                title,
                style: AppTypography.authHeadline.copyWith(
                  color: AppTheme.isLight(context)
                      ? AppTheme.lightOnSurface
                      : AppTheme.defaultTextColor,
                ),
                textAlign: titleAlign,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: Text(
              subtitle!,
              style: AppTypography.authSmallBody,
              textAlign: subtitleAlign,
            ),
          ),
        ],
        ...belowSubtitle,
      ],
    );
  }
}
