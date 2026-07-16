import 'package:flutter/material.dart';

import '../constants/bottom_nav_assets.dart';
import '../theme/bottom_nav_figma_tokens.dart';
import 'create_menu_style_row.dart';

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
          CreateMenuStyleRow(
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
