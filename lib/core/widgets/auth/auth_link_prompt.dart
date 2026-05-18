import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/app_typography.dart';

/// "Already have an account? **Sign in**" style footer link.
class AuthLinkPrompt extends StatelessWidget {
  const AuthLinkPrompt({
    super.key,
    required this.prompt,
    required this.actionLabel,
    required this.onActionTap,
  });

  final String prompt;
  final String actionLabel;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RichText(
        text: TextSpan(
          style: AppTypography.authSmallBody,
          children: [
            TextSpan(text: prompt),
            TextSpan(
              text: actionLabel,
              style: AppTypography.authSmallBodyBold,
              recognizer: TapGestureRecognizer()..onTap = onActionTap,
            ),
          ],
        ),
      ),
    );
  }
}
