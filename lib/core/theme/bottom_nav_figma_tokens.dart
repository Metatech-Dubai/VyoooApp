import 'package:flutter/material.dart';

import '../../screens/profile/profile_figma_tokens.dart';

/// Scaled bottom-nav measurements for the current screen (Figma 375×351 pill).
@immutable
class BottomNavLayout {
  const BottomNavLayout({required this.scale});

  /// Figma phone frame width.
  static const double designArtboardWidth = 375;

  /// Pill width on the Figma artboard (375 − 12 − 12).
  static const double designPillWidth = 351;

  final double scale;

  double s(double designPx) => designPx * scale;

  static double scaleFor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= 0) return 1;
    return (width / designArtboardWidth).clamp(0.85, 1.12);
  }

  factory BottomNavLayout.of(BuildContext context) =>
      BottomNavLayout(scale: scaleFor(context));

  double get horizontalMargin => s(BottomNavFigmaTokens.horizontalMargin);
  double get pillRadius => s(BottomNavFigmaTokens.pillRadius);
  double get pillInnerRadius => s(BottomNavFigmaTokens.pillInnerRadius);
  double get barHeight => s(BottomNavFigmaTokens.barHeight);
  double get pillContentLeftInset =>
      s(BottomNavFigmaTokens.pillContentLeftInset);
  double get pillContentRightInset =>
      s(BottomNavFigmaTokens.pillContentRightInset);
  double get pillContentVerticalInset =>
      s(BottomNavFigmaTokens.pillContentVerticalInset);
  double get navRowContentHeight =>
      s(BottomNavFigmaTokens.navRowContentHeight);
  double get iconGroupWidth => s(BottomNavFigmaTokens.iconGroupWidth);
  double get iconGroupHeight => s(BottomNavFigmaTokens.iconGroupHeight);
  double get tabSlotWidth => s(BottomNavFigmaTokens.tabSlotWidth);
  double get tabSlotHeight => s(BottomNavFigmaTokens.tabSlotHeight);
  double get tabGap => s(BottomNavFigmaTokens.tabGap);
  double get profileToIconGroupGap =>
      s(BottomNavFigmaTokens.profileToIconGroupGap);
  double get profileAvatarSize => s(BottomNavFigmaTokens.profileAvatarSize);
  double get profileAvatarBorderWidth =>
      s(BottomNavFigmaTokens.profileAvatarBorderWidth);
  double get createMenuToNavGap => s(BottomNavFigmaTokens.createMenuToNavGap);
  double get createMenuWidth => s(BottomNavFigmaTokens.createMenuWidth);

  List<BoxShadow> get pillShadow => [
        BoxShadow(
          color: const Color(0x1A000000),
          blurRadius: s(3),
          offset: Offset(0, s(4)),
        ),
        BoxShadow(
          color: const Color(0x1A000000),
          blurRadius: s(7.5),
          offset: Offset(0, s(10)),
        ),
      ];
}

/// Bottom navigation measurements (Figma light pill + create menu).
abstract final class BottomNavFigmaTokens {
  static const Color pillFill = ProfileFigmaTokens.screenBackground;
  static const Color iconColor = ProfileFigmaTokens.primaryText;

  /// Floating pill corner radius (Figma capsule).
  static const double pillRadius = 32;

  /// Horizontal inset for the floating pill (Figma 375 frame → 12px each side).
  static const double horizontalMargin = 12;

  /// Pill bar height (Figma 64px).
  static const double barHeight = 64;

  /// Frame 2147225001 — icon row inside the 351×64 pill.
  static const double pillContentLeftInset = 21;
  static const double pillContentRightInset = 6;
  static const double navRowContentWidth = 324;
  static const double navRowContentHeight = 56;

  /// Profile avatar (rect x=301 y=6, 56×56, 2px stroke) — 4px vertical inset in pill.
  static const double profileAvatarSize = 56;
  static const double pillContentVerticalInset = 4;

  /// Frame 2147224736 — first four tabs.
  static const double iconGroupWidth = 252;
  static const double iconGroupHeight = 40;
  static const double tabSlotWidth = 48;
  static const double tabSlotHeight = 40;
  static const double tabGap = 20;
  static const double profileToIconGroupGap = 16;

  /// Create menu stack (Figma 100×212).
  static const double createMenuWidth = 100;
  static const double createMenuRowHeight = 36;
  static const double createMenuRowRadius = 16;
  static const double createMenuRowGap = 6;
  static const double createMenuIconCircleSize = 30;
  static const double createMenuIconInset = 4;
  static const Color createMenuRowFill = pillFill;
  static const Color createMenuIconCircleFill = Color(0xFFE6E6E6);
  static const Color createMenuLabelColor = Color(0xFF4D4D4D);

  static const double createMenuLabelFontSize = 14;
  static const FontWeight createMenuLabelWeight = FontWeight.w500;

  /// Gap between create menu stack and nav pill.
  static const double createMenuToNavGap = 16;

  static const Duration createMenuAnimation = Duration(milliseconds: 260);
  static const Curve createMenuCurve = Curves.easeOutCubic;

  static const List<BoxShadow> createMenuRowShadow = <BoxShadow>[];

  /// Figma pill drop shadows (filter1_dd: σ=3 dy=4 + σ=7.5 dy=10 @ 10% black).
  static const List<BoxShadow> pillShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 3,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 7.5,
      offset: Offset(0, 10),
    ),
  ];

  /// Inset hairline stroke on the pill (rect 12.5×2.5, 350×63, rx=31.5).
  static const double pillInnerRadius = 31.5;
  static const Color pillStrokeColor = Color(0xFFDBC0C6);
  static const double pillStrokeOpacity = 0.2;

  /// Broadcast icon optical nudge inside the 48×40 tab slot.
  static const double broadcastIconOpticalOffsetX = -0.5;
  static const double broadcastIconOpticalOffsetY = -2.5;

  /// Profile avatar ring (Figma rect 56×56, stroke 2px #000000).
  static const double profileAvatarBorderWidth = 2;
  static const Color profileAvatarBorderColor = Color(0xFF000000);

  /// Slight upward bias so faces stay centered in the nav circle.
  static const double profilePhotoVerticalBias = -0.15;
}

/// Create hub actions from the bottom-nav plus menu.
enum BottomNavCreateAction {
  vr,
  post,
  reel,
  story,
  live,
}
