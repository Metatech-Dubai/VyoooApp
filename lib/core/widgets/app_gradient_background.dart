import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_light_surface.dart';
import '../theme/app_theme.dart';

enum GradientType {
  auth,
  authRadial,
  authFlow,
  onboarding,
  dob,
  profile,
  feed,
  main,
  profileCardBackground,
  premiumDark,
}

/// Full-screen page background. Renders solid white with light theme defaults.
/// [GradientType] is kept for call-site compatibility; all types use white.
class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({
    super.key,
    required this.child,
    this.type = GradientType.main,
    this.backgroundAsset,
  });

  final Widget child;
  final GradientType type;

  /// Legacy auth-flow asset param — ignored; white background is used instead.
  final String? backgroundAsset;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.lightEdgeToEdgeOverlay,
        child: ColoredBox(
          color: AppLightSurface.background,
          child: SafeArea(
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: AppLightSurface.primaryText),
              child: IconTheme.merge(
                data: const IconThemeData(color: AppLightSurface.icon),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
