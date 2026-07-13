import 'package:flutter/material.dart';

import '../../screens/profile/profile_figma_tokens.dart';

/// Bottom navigation measurements (Figma light pill + create menu).
abstract final class BottomNavFigmaTokens {
  static const Color pillFill = ProfileFigmaTokens.screenBackground;
  static const Color iconColor = ProfileFigmaTokens.primaryText;

  /// Floating pill corner radius (Figma capsule).
  static const double pillRadius = 32;

  /// Horizontal inset for the floating pill.
  static const double horizontalMargin = 20;

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
  static const double createMenuToNavGap = 12;

  static const Duration createMenuAnimation = Duration(milliseconds: 260);
  static const Curve createMenuCurve = Curves.easeOutCubic;

  static const List<BoxShadow> createMenuRowShadow = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 4,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> pillShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  /// Broadcast artboard is bottom-heavy (camera body) — nudge up vs home/chat/plus.
  static const double broadcastIconOpticalOffsetY = -3;

  /// Profile avatar ring (Figma 56×56, 2px #000000 center stroke).
  static const double profileAvatarBorderWidth = 2;
  static const Color profileAvatarBorderColor = Color(0xFF000000);
}

/// Create hub actions from the bottom-nav plus menu.
enum BottomNavCreateAction {
  vr,
  post,
  reel,
  story,
  live,
}
