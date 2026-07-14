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
    required this.layout,
  });

  /// `0` hidden → `1` fully visible (parent drives open/close).
  final double progress;
  final ValueChanged<BottomNavCreateAction> onAction;
  final BottomNavLayout layout;

  static const List<({BottomNavCreateAction action, String label, String icon})>
      _items = [
    (action: BottomNavCreateAction.vr, label: 'VR', icon: BottomNavAssets.createMenuVr),
    (action: BottomNavCreateAction.post, label: 'Post', icon: BottomNavAssets.createMenuPost),
    (action: BottomNavCreateAction.reel, label: 'Reel', icon: BottomNavAssets.createMenuReel),
    (action: BottomNavCreateAction.story, label: 'Story', icon: BottomNavAssets.createMenuStory),
    (action: BottomNavCreateAction.live, label: 'Live', icon: BottomNavAssets.createMenuLive),
  ];

  double totalDesignHeight() {
    final rowHeight = layout.s(BottomNavFigmaTokens.createMenuRowHeight);
    final rowGap = layout.s(BottomNavFigmaTokens.createMenuRowGap);
    return _items.length * rowHeight + (_items.length - 1) * rowGap;
  }

  @override
  Widget build(BuildContext context) {
    final reveal = progress.clamp(0.0, 1.0);
    if (reveal <= 0) return const SizedBox.shrink();

    final rowGap = layout.s(BottomNavFigmaTokens.createMenuRowGap);
    final menu = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) SizedBox(height: rowGap),
          _CreateMenuRow(
            layout: layout,
            label: _items[i].label,
            iconAsset: _items[i].icon,
            progress: _staggeredProgress(reveal, i),
            onTap: () => onAction(_items[i].action),
          ),
        ],
      ],
    );

    // Once fully open, skip clip so the last row (Live) is never cropped.
    if (reveal >= 0.999) {
      return IgnorePointer(
        ignoring: false,
        child: SizedBox(
          width: layout.createMenuWidth,
          child: menu,
        ),
      );
    }

    return IgnorePointer(
      ignoring: reveal < 0.85,
      child: SizedBox(
        width: layout.createMenuWidth,
        child: ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: reveal.clamp(0.001, 1.0),
            child: Opacity(
              opacity: reveal,
              child: menu,
            ),
          ),
        ),
      ),
    );
  }

  /// Stagger that always finishes at 1.0 when [master] is 1.0 (including Live).
  static double _staggeredProgress(double master, int index) {
    final start = index * 0.06;
    final span = 1.0 - start;
    if (span <= 0) return master >= 1 ? 1 : 0;
    if (master <= start) return 0;
    return ((master - start) / span).clamp(0.0, 1.0);
  }
}

class _CreateMenuRow extends StatelessWidget {
  const _CreateMenuRow({
    required this.layout,
    required this.label,
    required this.iconAsset,
    required this.progress,
    required this.onTap,
  });

  final BottomNavLayout layout;
  final String label;
  final String iconAsset;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final slideY = (1 - progress) * layout.s(-6);
    final rowHeight = layout.s(BottomNavFigmaTokens.createMenuRowHeight);
    final rowRadius = layout.s(BottomNavFigmaTokens.createMenuRowRadius);
    final iconCircleSize = layout.s(BottomNavFigmaTokens.createMenuIconCircleSize);
    final iconInset = layout.s(BottomNavFigmaTokens.createMenuIconInset);

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
                    child: SvgPicture.asset(
                      iconAsset,
                      width: layout.s(18),
                      height: layout.s(18),
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: layout.s(8)),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: layout.s(BottomNavFigmaTokens.createMenuLabelFontSize),
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
