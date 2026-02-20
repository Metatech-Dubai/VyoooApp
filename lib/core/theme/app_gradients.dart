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

  /// Subscription plan cards (dark purple to pink).
  static const LinearGradient subscriptionCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF21002B),
      Color(0xFF490038),
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

  /// VR locked view bottom card (dark translucent).
  static const LinearGradient vrPaymentCardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xE614001F),
      Color(0xF021002B),
      Color(0xF0490038),
    ],
  );

  /// Story avatar ring (pink gradient border).
  static const LinearGradient storyRingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFD10057),
      Color(0xFFFF6B9D),
    ],
  );

  /// Pink primary button (e.g. Get started).
  static const LinearGradient vrGetStartedButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFDE106B),
      Color(0xFFF81945),
    ],
  );

  /// Download prompt "Subscribe Now" button (gold to orange-brown).
  static const LinearGradient subscribeNowButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFE8C547),
      Color(0xFFD4A84B),
      Color(0xFFB8862E),
    ],
  );
}
