import 'package:flutter/material.dart';

/// 🔴 Do NOT define gradients inside screens.
/// Always use AppGradients.
/// This ensures brand consistency across the entire app.

class AppGradients {
  AppGradients._();

  /// Auth (exact Figma 6-stop gradient)
  static const LinearGradient authGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF020109),
      Color(0xFF07010F),
      Color(0xFF21002B),
      Color(0xFF490038),
      Color(0xFFDE106B),
      Color(0xFFF81945),
    ],
    stops: [
      0.0,
      0.19,
      0.42,
      0.54,
      0.77,
      1.0,
    ],
  );

  static const LinearGradient onboardingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF07010F),
      Color(0xFF21002B),
      Color(0xFF490038),
      Color(0xFFDE106B),
    ],
  );

  static const LinearGradient dobGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFDE106B),
      Color(0xFF490038),
      Color(0xFF020109),
    ],
  );

  static const LinearGradient profileGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF14001F),
      Color(0xFF4A003F),
      Color(0xFFDE106B),
    ],
  );

  static const LinearGradient feedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF14001F),
      Color(0xFF2A002B),
      Color(0xFF490038),
    ],
  );
}
