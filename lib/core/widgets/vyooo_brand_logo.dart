import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Vyooo wordmark for auth and onboarding headers.
///
/// [size] is the layout **height** in logical pixels. The PNG is square with
/// extra transparent padding, so [contentScale] zooms the asset inside that
/// slot — increasing [size] always changes what you see on screen.
class VyoooBrandLogo extends StatelessWidget {
  const VyoooBrandLogo({
    super.key,
    this.width,
    this.size,
    this.height,
    this.contentScale = defaultContentScale,
    this.center = true,
    this.alignment = Alignment.center,
  }) : svgAssetPath = null;

  static const String assetPath = 'assets/BrandLogo/Logo2.png';

  /// Figma vector wordmark (#000000) for auth + onboarding headers.
  static const String wordmarkSvgAssetPath =
      'assets/BrandLogo/vyooo_wordmark_onboarding.svg';

  static const double _wordmarkSvgAspectRatio = 128 / 47;

  /// Default layout height (auth headers).
  static const double defaultHeight = 52;

  /// Zoom inside the layout box to offset square-asset transparent padding.
  static const double defaultContentScale = 2.25;

  /// Auth sign-in / sign-up — wide wordmark, tight crop (Figma).
  static const double authContentScale = 2.45;

  /// Inner settings/account header — smaller slot, less zoom (matches title scale).
  static const double innerHeaderContentScale = 1.55;

  /// Compact wordmark for [SettingsInnerAppBar] and similar inner screens.
  const VyoooBrandLogo.innerHeader({super.key})
      : width = null,
        size = AppSizes.settingsInnerLogoHeight,
        height = null,
        contentScale = innerHeaderContentScale,
        center = false,
        alignment = Alignment.centerRight,
        svgAssetPath = null;

  /// Auth headers — Figma SVG wordmark (#000000 on light surfaces).
  const VyoooBrandLogo.auth({super.key})
      : width = null,
        size = AppSizes.authLogoHeight,
        height = null,
        contentScale = authContentScale,
        center = true,
        alignment = Alignment.center,
        svgAssetPath = wordmarkSvgAssetPath;

  /// Onboarding headers — same Figma SVG wordmark as [VyoooBrandLogo.auth].
  const VyoooBrandLogo.onboarding({super.key})
      : width = null,
        size = AppSizes.authLogoHeight,
        height = null,
        contentScale = defaultContentScale,
        center = true,
        alignment = Alignment.center,
        svgAssetPath = wordmarkSvgAssetPath;

  /// Home feed overlay — left-aligned wordmark with lightbulb mark visible.
  const VyoooBrandLogo.feed({super.key})
      : width = null,
        size = AppSizes.feedLogoHeight,
        height = null,
        contentScale = 1.95,
        center = false,
        alignment = Alignment.centerLeft,
        svgAssetPath = null;

  final double? width;
  final double? size;
  final double? height;
  final double contentScale;
  final bool center;
  final AlignmentGeometry alignment;
  final String? svgAssetPath;

  double get _resolvedHeight => height ?? size ?? defaultHeight;

  @override
  Widget build(BuildContext context) {
    if (svgAssetPath != null) {
      return _buildSvgWordmark(context);
    }

    final isLight = AppTheme.isLight(context);
    final paintedHeight = _resolvedHeight * contentScale;

    Widget logo = SizedBox(
      height: _resolvedHeight,
      child: ClipRect(
        child: Align(
          alignment: alignment,
          child: _buildPngWordmark(
            paintedHeight: paintedHeight,
            tintBurgundy: isLight,
          ),
        ),
      ),
    );

    if (center) {
      logo = Center(child: logo);
    }

    return logo;
  }

  Widget _buildSvgWordmark(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    final layoutHeight = _resolvedHeight;
    final layoutWidth = width ?? layoutHeight * _wordmarkSvgAspectRatio;
    // Figma fill #000000 on white auth/onboarding shells; white on dark gradient.
    final fillColor = isLight ? AppTheme.lightOnSurface : AppTheme.primary;

    Widget logo = SvgPicture.asset(
      svgAssetPath!,
      height: layoutHeight,
      width: layoutWidth,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(fillColor, BlendMode.srcIn),
      semanticsLabel: 'Vyooo',
    );

    if (center) {
      logo = Center(child: logo);
    }

    return logo;
  }

  Widget _buildPngWordmark({
    required double paintedHeight,
    required bool tintBurgundy,
  }) {
    final image = Image.asset(
      assetPath,
      width: width,
      height: paintedHeight,
      fit: BoxFit.fitHeight,
      errorBuilder: (context, error, stackTrace) =>
          _errorFallback(context, tintBurgundy),
    );

    if (!tintBurgundy) return image;

    return ColorFiltered(
      colorFilter: const ColorFilter.mode(
        AppColors.authBrandBurgundy,
        BlendMode.srcIn,
      ),
      child: image,
    );
  }

  Widget _errorFallback(
    BuildContext context,
    bool isLight,
  ) {
    final fallbackSize = _resolvedHeight <= AppSizes.settingsInnerLogoHeight
        ? 14.0
        : (_resolvedHeight * 0.85).clamp(22.0, 42.0);
    return Text(
      'VyooO',
      style: AppTypography.brandFallback.copyWith(
        fontSize: fallbackSize,
        color: isLight ? AppTheme.lightOnSurface : AppTheme.primary,
      ),
    );
  }
}
