import 'package:flutter/material.dart';

import '../../theme/app_padding.dart';

/// Vertically and horizontally centers auth content; scrolls on small screens.
///
/// Children use [CrossAxisAlignment.stretch] so fields and buttons stay full width.
class AuthCenteredScrollBody extends StatelessWidget {
  const AuthCenteredScrollBody({super.key, required this.children});

  final List<Widget> children;

  double _availableHeight(BuildContext context, BoxConstraints constraints) {
    final media = MediaQuery.of(context);
    final fromMedia =
        media.size.height - media.padding.top - media.padding.bottom;
    if (constraints.maxHeight.isFinite && constraints.maxHeight > 0) {
      return constraints.maxHeight;
    }
    return fromMedia;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = _availableHeight(context, constraints);
        return SingleChildScrollView(
          padding: AppPadding.authFormHorizontal,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        );
      },
    );
  }
}
