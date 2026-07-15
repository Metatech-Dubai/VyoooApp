import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Shared light page chrome (settings, account, wallet, etc.).
abstract final class AppLightSurface {
  AppLightSurface._();

  static const Color background = Colors.white;
  static const Color primaryText = AppColors.profileDisplayName;
  static const Color secondaryText = Color(0xFF5A5A5A);
  static const Color mutedText = AppColors.profileTabUnselectedLabel;
  static const Color cardFill = AppColors.profileStatChipBackground;
  static const Color border = Color(0xFFE5E5E5);
  static const Color divider = Color(0xFFF0F0F0);
  static const Color icon = AppColors.profileDisplayName;
  static const Color chevron = Color(0xFF9E9E9E);
}
