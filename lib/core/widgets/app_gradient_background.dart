import 'package:flutter/material.dart';

import '../theme/app_background_assets.dart';
import '../theme/app_gradients.dart';

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

/// Reusable full-screen gradient background.
/// Handles SafeArea internally. Padding is left to each screen.
class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({
    super.key,
    required this.child,
    this.type = GradientType.main,
    this.backgroundAsset,
  });

  final Widget child;
  final GradientType type;

  /// When [type] is [GradientType.authFlow], use this asset instead of a random pick.
  final String? backgroundAsset;

  Gradient get _gradient {
    switch (type) {
      case GradientType.onboarding:
        return AppGradients.onboardingGradient;
      case GradientType.dob:
        return AppGradients.dobGradient;
      case GradientType.profile:
        return AppGradients.profileGradient;
      case GradientType.feed:
        return AppGradients.feedGradient;
      case GradientType.auth:
        return AppGradients.authScreenRadialGradient;
      case GradientType.authFlow:
        throw StateError('authFlow uses image background');
      case GradientType.authRadial:
        return AppGradients.authRadialMainGlow;
      case GradientType.main:
        return AppGradients.mainBackgroundGradient;
      case GradientType.profileCardBackground:
        return AppGradients.profileCardBackground;
      case GradientType.premiumDark:
        return AppGradients.premiumDarkGradient;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (type == GradientType.authFlow) {
      return _AuthFlowImageBackground(
        assetPath: backgroundAsset,
        child: child,
      );
    }
    if (type == GradientType.authRadial) {
      return _AuthRadialLayeredBackground(child: child);
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(gradient: _gradient),
      child: SafeArea(child: child),
    );
  }
}

/// Auth / onboarding — one random [AppBackgroundAssets.authFlowBackgrounds] image per screen.
class _AuthFlowImageBackground extends StatefulWidget {
  const _AuthFlowImageBackground({
    required this.child,
    this.assetPath,
  });

  final Widget child;
  final String? assetPath;

  @override
  State<_AuthFlowImageBackground> createState() =>
      _AuthFlowImageBackgroundState();
}

class _AuthFlowImageBackgroundState extends State<_AuthFlowImageBackground> {
  late final String _asset;

  @override
  void initState() {
    super.initState();
    _asset = widget.assetPath ?? AppBackgroundAssets.randomAuthFlowBackground();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(_asset),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(child: widget.child),
    );
  }
}

/// Figma sign-up background: dark base + bottom glow + top-left accent.
class _AuthRadialLayeredBackground extends StatelessWidget {
  const _AuthRadialLayeredBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppGradients.authScreenBaseColor),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppGradients.authRadialMainGlow,
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppGradients.authRadialTopLeftGlow,
          ),
        ),
        SafeArea(child: child),
      ],
    );
  }
}
