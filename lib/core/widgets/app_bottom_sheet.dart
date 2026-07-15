import 'package:flutter/material.dart';

import '../theme/app_light_surface.dart';

/// Shared white bottom sheet chrome (drag handle, container, decoration).
abstract final class AppBottomSheet {
  AppBottomSheet._();

  static const double defaultTopRadius = 20;
  static const BorderRadius topBorderRadius = BorderRadius.vertical(
    top: Radius.circular(defaultTopRadius),
  );

  static BoxDecoration decoration({double topRadius = defaultTopRadius}) {
    return BoxDecoration(
      color: AppLightSurface.background,
      borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
    );
  }

  /// Standard drag pill at the top of bottom sheets.
  static Widget dragHandle({
    double width = 48,
    double height = 4,
    EdgeInsetsGeometry padding = const EdgeInsets.only(top: 8, bottom: 12),
  }) {
    return Padding(
      padding: padding,
      child: Center(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppLightSurface.border,
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),
    );
  }

  /// White rounded container for modal bottom sheet content.
  static Widget shell({
    required Widget child,
    double topRadius = defaultTopRadius,
    bool useSafeArea = true,
  }) {
    final body = useSafeArea ? SafeArea(top: false, child: child) : child;
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
      child: Container(
        decoration: decoration(topRadius: topRadius),
        child: body,
      ),
    );
  }
}
