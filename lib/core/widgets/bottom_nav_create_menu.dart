import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/bottom_nav_assets.dart';
import '../theme/app_fonts.dart';
import '../theme/bottom_nav_figma_tokens.dart';

/// Animated create hub menu above the bottom nav pill (Figma 100×212 stack).
class BottomNavCreateMenu extends StatelessWidget {
  const BottomNavCreateMenu({
    super.key,
    required this.progress,
    required this.onAction,
  });

  /// `0` hidden → `1` fully visible (parent drives open/close).
  final double progress;
  final ValueChanged<BottomNavCreateAction> onAction;

  static const List<({BottomNavCreateAction action, String label, String icon})>
      _items = [
    (action: BottomNavCreateAction.vr, label: 'VR', icon: BottomNavAssets.createMenuVr),
    (action: BottomNavCreateAction.post, label: 'Post', icon: BottomNavAssets.createMenuPost),
    (action: BottomNavCreateAction.reel, label: 'Reel', icon: BottomNavAssets.createMenuReel),
    (action: BottomNavCreateAction.story, label: 'Story', icon: BottomNavAssets.createMenuStory),
    (action: BottomNavCreateAction.live, label: 'Live', icon: BottomNavAssets.createMenuLive),
  ];

  static double totalDesignHeight() {
    final rowHeight = BottomNavFigmaTokens.createMenuRowHeight;
    final rowGap = BottomNavFigmaTokens.createMenuRowGap;
    return _items.length * rowHeight + (_items.length - 1) * rowGap;
  }

  @override
  Widget build(BuildContext context) {
    final reveal = progress.clamp(0.0, 1.0);
    if (reveal <= 0) return const SizedBox.shrink();

    final rowGap = BottomNavFigmaTokens.createMenuRowGap;

    return IgnorePointer(
      ignoring: reveal < 0.85,
      child: SizedBox(
        width: BottomNavFigmaTokens.createMenuWidth,
        child: ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: reveal.clamp(0.001, 1.0),
            child: Opacity(
              opacity: reveal,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _items.length; i++) ...[
                    if (i > 0) SizedBox(height: rowGap),
                    _CreateMenuRow(
                      label: _items[i].label,
                      iconAsset: _items[i].icon,
                      progress: _staggeredProgress(reveal, i),
                      onTap: () => onAction(_items[i].action),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static double _staggeredProgress(double master, int index) {
    final start = index * 0.08;
    final end = start + 0.72;
    if (master <= start) return 0;
    if (master >= end) return 1;
    return ((master - start) / (end - start)).clamp(0.0, 1.0);
  }
}

class _CreateMenuRow extends StatelessWidget {
  const _CreateMenuRow({
    required this.label,
    required this.iconAsset,
    required this.progress,
    required this.onTap,
  });

  final String label;
  final String iconAsset;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final slideY = (1 - progress) * 8;
    return Transform.translate(
      offset: Offset(0, slideY),
      child: Opacity(
        opacity: progress.clamp(0.0, 1.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius:
                BorderRadius.circular(BottomNavFigmaTokens.createMenuRowRadius),
            child: Ink(
              height: BottomNavFigmaTokens.createMenuRowHeight,
              decoration: BoxDecoration(
                color: BottomNavFigmaTokens.createMenuRowFill,
                borderRadius: BorderRadius.circular(
                  BottomNavFigmaTokens.createMenuRowRadius,
                ),
                boxShadow: BottomNavFigmaTokens.createMenuRowShadow,
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: BottomNavFigmaTokens.createMenuIconInset,
                  ),
                  Container(
                    width: BottomNavFigmaTokens.createMenuIconCircleSize,
                    height: BottomNavFigmaTokens.createMenuIconCircleSize,
                    decoration: const BoxDecoration(
                      color: BottomNavFigmaTokens.createMenuIconCircleFill,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      iconAsset,
                      width: 18,
                      height: 18,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: BottomNavFigmaTokens.createMenuLabelFontSize,
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
}
