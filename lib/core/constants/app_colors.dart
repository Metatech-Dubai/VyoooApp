import 'package:flutter/material.dart';

/// Shared color constants for Vyooo. Use these instead of hardcoded hex.
class AppColors {
  AppColors._();

  static const Color pink = Color(0xFFD10057);
  static const Color darkPurple = Color(0xFF5A003F);
  static const Color lightGold = Color(0xFFE8C547);

  /// Bottom sheets (comments, share)
  static const Color sheetBackground = Color(0xFF2A1B2E);
  static const Color sheetBackgroundShare = Color(0xFF2A2530);

  /// Actions / semantic
  static const Color deleteRed = Color(0xFFE53935);
  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color linkBlue = Color(0xFF2196F3);
  static const Color instagramPink = Color(0xFFE1306C);
  static const Color iconBackgroundDark = Color(0xFF2A2A2A);

  /// Instagram gradient (share action)
  static const List<Color> instagramGradient = [
    Color(0xFFF77737),
    Color(0xFFE1306C),
    Color(0xFF833AB4),
  ];
}
