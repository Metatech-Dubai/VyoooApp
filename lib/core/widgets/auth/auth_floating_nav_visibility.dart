import 'package:flutter/material.dart';

/// Whether the floating auth back control should be shown.
bool shouldShowAuthFloatingBack(
  BuildContext context, {
  required bool hasBackHandler,
  bool alwaysShowBack = false,
}) {
  if (!hasBackHandler) return false;
  if (alwaysShowBack) return true;

  final route = ModalRoute.of(context);
  final navigator = Navigator.of(context);
  final isNavigatorRoot =
      route != null && route.isFirst && !navigator.canPop();
  if (isNavigatorRoot) return false;

  return navigator.canPop();
}
