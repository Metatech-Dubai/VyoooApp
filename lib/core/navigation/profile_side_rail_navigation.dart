import 'package:flutter/material.dart';

import '../../screens/profile/profile_figma_tokens.dart';

/// Full-screen route that slides in from the left (profile side rail).
Future<T?> openProfileSideRailScreen<T>(
  BuildContext context, {
  required Widget child,
}) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      fullscreenDialog: true,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: ProfileFigmaTokens.profileSideDrawerAnimation,
      reverseTransitionDuration: ProfileFigmaTokens.profileSideDrawerAnimation,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    ),
  );
}
