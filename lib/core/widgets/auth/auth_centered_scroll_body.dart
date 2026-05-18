import 'package:flutter/material.dart';

import '../../theme/app_padding.dart';

/// Vertically and horizontally centers auth content; scrolls on small screens.
///
/// Children use [CrossAxisAlignment.stretch] so fields and buttons stay full width.
class AuthCenteredScrollBody extends StatelessWidget {
  const AuthCenteredScrollBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: AppPadding.authFormHorizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
