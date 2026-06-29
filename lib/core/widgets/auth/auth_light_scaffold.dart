import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_padding.dart';
import '../../theme/app_theme.dart';

/// White auth/onboarding shell with light status-bar icons and [AppTheme.light].
class AuthLightScaffold extends StatelessWidget {
  const AuthLightScaffold({
    super.key,
    required this.body,
    this.padding,
    this.scrollable = true,
    this.useSafeArea = true,
    this.stackChildren = const [],
  });

  final Widget body;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;
  final bool useSafeArea;
  final List<Widget> stackChildren;

  @override
  Widget build(BuildContext context) {
    Widget content = body;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    if (scrollable) {
      content = SingleChildScrollView(child: content);
    }
    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return Theme(
      data: AppTheme.light,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.lightEdgeToEdgeOverlay,
        child: Scaffold(
          backgroundColor: AppTheme.lightScaffoldBackground,
          resizeToAvoidBottomInset: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: content),
              ...stackChildren,
            ],
          ),
        ),
      ),
    );
  }
}

/// Default horizontal inset for auth/onboarding forms.
const EdgeInsets authLightFormPadding = AppPadding.authFormHorizontal;
