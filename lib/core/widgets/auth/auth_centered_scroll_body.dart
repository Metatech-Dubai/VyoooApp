import 'package:flutter/material.dart';

import '../../theme/app_padding.dart';

/// Vertically centers auth content in the viewport; scrolls when it overflows.
///
/// Children use [CrossAxisAlignment.stretch] so fields and buttons stay full width.
/// Parent must provide bounded height (see [AuthLightScaffold] with
/// `scrollable: false`).
class AuthCenteredScrollBody extends StatelessWidget {
  const AuthCenteredScrollBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.maxHeight;
        return SingleChildScrollView(
          padding: AppPadding.authFormHorizontal,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: viewportHeight > 0 ? viewportHeight : 0,
            ),
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
