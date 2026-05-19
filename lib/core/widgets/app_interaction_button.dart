import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// Standard interaction button used across the app (reels, stories, posts, etc).
/// Vertical layout: icon above count text. Use [count] empty for icon-only (e.g. Crown, More).
class AppInteractionButton extends StatelessWidget {
  const AppInteractionButton({
    super.key,
    this.icon,
    this.iconAsset,
    this.iconAssetActive,
    required this.count,
    this.isActive = false,
    this.onTap,
    this.activeColor = const Color(0xFFD10057),
    this.defaultColor = Colors.white,
    this.iconColor,
    this.countColor,
    this.iconSize = 28,
    this.textSize = 12,
    this.countTextStyle,
    this.colorizeAsset = true,
    this.spacing = 4,
  }) : assert(
         icon != null || iconAsset != null || iconAssetActive != null,
         'Provide icon or iconAsset',
       );

  final IconData? icon;
  final String? iconAsset;

  /// When [isActive], shown instead of [iconAsset] (e.g. saved vs unsaved).
  final String? iconAssetActive;

  /// When false, PNG assets render without a color tint (full-color icons).
  final bool colorizeAsset;
  final String count;
  final bool isActive;
  final VoidCallback? onTap;
  final Color activeColor;
  final Color defaultColor;
  /// Override icon color (e.g. yellow for Crown). If null, uses active/default.
  final Color? iconColor;

  /// Count label color. If null, matches the icon tint (except when only icon is active).
  final Color? countColor;
  final double iconSize;
  final double textSize;
  final TextStyle? countTextStyle;
  final double spacing;

  String? get _resolvedAsset {
    if (isActive && iconAssetActive != null) return iconAssetActive;
    return iconAsset;
  }

  Widget _buildIcon(Color color) {
    final asset = _resolvedAsset;
    if (asset != null) {
      return Image.asset(
        asset,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        color: colorizeAsset ? (iconColor ?? color) : iconColor,
        errorBuilder: (_, error, stackTrace) => Icon(
          icon ?? Icons.image_not_supported_outlined,
          size: iconSize,
          color: color,
        ),
      );
    }
    return Icon(icon, size: iconSize, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final iconTint = iconColor ?? (isActive ? activeColor : defaultColor);
    final countTint = countColor ?? iconTint;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(iconTint),
          if (count.isNotEmpty) ...[
            SizedBox(height: spacing),
            Text(
              count,
              style: (countTextStyle ?? AppTypography.feedReelMetric)
                  .copyWith(
                fontSize: countTextStyle == null ? textSize : null,
                color: countTint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
