import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_fonts.dart';
import '../theme/bottom_nav_figma_tokens.dart';

/// Pill row used by the bottom-nav create hub and matching dropdown menus.
class CreateMenuStyleRow extends StatelessWidget {
  const CreateMenuStyleRow({
    super.key,
    required this.layout,
    required this.label,
    required this.onTap,
    this.iconAsset,
    this.icon,
    this.progress = 1.0,
    this.width,
  }) : assert(iconAsset != null || icon != null);

  final BottomNavLayout layout;
  final String label;
  final VoidCallback onTap;
  final String? iconAsset;
  final IconData? icon;
  final double progress;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final slideY = (1 - progress) * layout.s(-6);
    final rowHeight = layout.s(BottomNavFigmaTokens.createMenuRowHeight);
    final rowRadius = layout.s(BottomNavFigmaTokens.createMenuRowRadius);
    final iconCircleSize = layout.s(BottomNavFigmaTokens.createMenuIconCircleSize);
    final iconInset = layout.s(BottomNavFigmaTokens.createMenuIconInset);
    final rowWidth = width ?? layout.createMenuWidth;

    return Transform.translate(
      offset: Offset(0, slideY),
      child: Opacity(
        opacity: progress.clamp(0.0, 1.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(rowRadius),
            child: Ink(
              width: rowWidth,
              height: rowHeight,
              decoration: BoxDecoration(
                color: BottomNavFigmaTokens.createMenuRowFill,
                borderRadius: BorderRadius.circular(rowRadius),
                boxShadow: BottomNavFigmaTokens.createMenuRowShadow,
              ),
              child: Row(
                children: [
                  SizedBox(width: iconInset),
                  Container(
                    width: iconCircleSize,
                    height: iconCircleSize,
                    decoration: const BoxDecoration(
                      color: BottomNavFigmaTokens.createMenuIconCircleFill,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: _buildLeading(iconCircleSize),
                  ),
                  SizedBox(width: layout.s(8)),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize:
                          layout.s(BottomNavFigmaTokens.createMenuLabelFontSize),
                      fontWeight: BottomNavFigmaTokens.createMenuLabelWeight,
                      color: BottomNavFigmaTokens.createMenuLabelColor,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(double iconCircleSize) {
    final iconSize = layout.s(18);
    final asset = iconAsset;
    if (asset != null) {
      return SvgPicture.asset(
        asset,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
      );
    }
    return Icon(
      icon,
      size: iconSize,
      color: BottomNavFigmaTokens.createMenuLabelColor,
    );
  }
}
