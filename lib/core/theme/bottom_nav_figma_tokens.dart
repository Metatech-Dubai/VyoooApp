import 'package:flutter/material.dart';

import '../../screens/profile/profile_figma_tokens.dart';

/// Bottom navigation measurements (Figma light pill + create menu).
abstract final class BottomNavFigmaTokens {
  static const Color pillFill = ProfileFigmaTokens.screenBackground;
  static const Color iconColor = ProfileFigmaTokens.primaryText;

  /// Floating pill corner radius (Figma capsule).
  static const double pillRadius = 32;

  /// Horizontal inset for the floating pill (Figma 375 frame → 12px each side).
  static const double horizontalMargin = 12;

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
