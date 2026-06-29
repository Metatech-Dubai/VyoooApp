import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_theme.dart';

/// Shared text-field chrome for light auth surfaces and dark app surfaces.
abstract final class AppTextFieldStyle {
  static bool isLight(BuildContext context) => AppTheme.isLight(context);

  /// iOS keyboard — must be set per field; not inferred reliably from [ThemeData].
  static Brightness keyboardAppearance(BuildContext context) =>
      isLight(context) ? Brightness.light : Brightness.dark;

  static Color cursorColor(BuildContext context) =>
      isLight(context) ? AppColors.authBrandBurgundy : AppTheme.primary;

  static Color selectionFillColor(BuildContext context) =>
      cursorColor(context).withValues(alpha: 0.28);

  static Color selectionHandleColor(BuildContext context) => cursorColor(context);

  static TextSelectionThemeData textSelectionTheme(BuildContext context) {
    return TextSelectionThemeData(
      cursorColor: cursorColor(context),
      selectionColor: selectionFillColor(context),
      selectionHandleColor: selectionHandleColor(context),
    );
  }

  static InputBorder enabledUnderlineBorder(BuildContext context) {
    return UnderlineInputBorder(
      borderSide: BorderSide(
        color: isLight(context)
            ? AppTheme.lightUnfocusedUnderline
            : AppTheme.unfocusedUnderlineColor,
      ),
    );
  }

  static InputBorder focusedUnderlineBorder(BuildContext context) {
    return UnderlineInputBorder(
      borderSide: BorderSide(
        color: isLight(context)
            ? AppColors.authBrandBurgundy
            : AppTheme.focusedUnderlineColor,
        width: isLight(context) ? 2 : 1,
      ),
    );
  }

  static InputDecoration underlineDecoration(
    BuildContext context, {
  required InputDecoration decoration,
  }) {
    return decoration.copyWith(
      enabledBorder: enabledUnderlineBorder(context),
      focusedBorder: focusedUnderlineBorder(context),
      border: enabledUnderlineBorder(context),
    );
  }
}
