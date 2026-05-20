import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_fonts.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Global theme for Vyooo app.
/// Scaffold background: Black, primary: White, underline-only inputs.
class AppTheme {
  AppTheme._();

  // Colors
  static const Color scaffoldBackground = Colors.black;
  static const Color primary = Colors.white;
  static const Color buttonBackground = Colors.white;
  static const Color buttonTextColor = Colors.black;
  static const Color defaultTextColor = Colors.white;
  static const Color hintTextColor = White54.value;
  static const Color unfocusedUnderlineColor = White24.value;
  static const Color focusedUnderlineColor = Colors.white;
  static const Color secondaryTextColor = White70.value;
  static const Color searchBarColor = White24.value;

  /// Edge-to-edge overlay: icon brightness only (no status/navigation bar colors).
  static const SystemUiOverlayStyle edgeToEdgeOverlay = SystemUiOverlayStyle(
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppFonts.body,
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: edgeToEdgeOverlay,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      scaffoldBackgroundColor: scaffoldBackground,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        surface: scaffoldBackground,
        primary: primary,
        onPrimary: buttonTextColor,
        onSurface: defaultTextColor,
      ),
      textTheme: Typography.material2021(platform: TargetPlatform.iOS)
          .white
          .apply(
            fontFamily: AppFonts.body,
            bodyColor: defaultTextColor,
            displayColor: defaultTextColor,
          )
          .copyWith(
            displayLarge: AppTypography.authHeadline,
            bodyLarge: AppTypography.input,
            bodyMedium: AppTypography.input,
            bodySmall: AppTypography.label,
            titleLarge: AppTypography.authHeadline.copyWith(fontSize: 32),
            titleMedium: AppTypography.toggleLabel,
            titleSmall: AppTypography.label,
            labelLarge: AppTypography.primaryButton,
            labelMedium: AppTypography.authSmallBody,
            labelSmall: AppTypography.authDividerLabel,
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          vertical: AppSpacing.storyItem,
        ),
        hintStyle: AppTypography.inputHint,
        labelStyle: AppTypography.input,
        floatingLabelStyle: AppTypography.input,
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: unfocusedUnderlineColor),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: focusedUnderlineColor),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBackground,
          foregroundColor: buttonTextColor,
          elevation: 0,
        ),
      ),
    );
  }
}

// Opacity-based whites for consistency with spec
class White54 {
  White54._();
  static const Color value = Color(0x8AFFFFFF);
}

class White70 {
  White70._();
  static const Color value = Color(0xB3FFFFFF);
}

class White24 {
  White24._();
  static const Color value = Color(0x3DFFFFFF);
}

class White10 {
  White10._();
  static const Color value = Color(0x1AFFFFFF);
}

class White40 {
  White40._();
  static const Color value = Color(0x66FFFFFF);
}

class White50 {
  White50._();
  static const Color value = Color(0x80FFFFFF);
}

class White60 {
  White60._();
  static const Color value = Color(0x99FFFFFF);
}

class White15 {
  White15._();
  static const Color value = Color(0x26FFFFFF);
}

/// Figma feed notification circle fill (#FFFFFF @ 30%).
class White30 {
  White30._();
  static const Color value = Color(0x4DFFFFFF);
}
