import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'auth_branded_dialog.dart';

/// Shown when a user picks a reserved username during onboarding.
class AuthReservedUsernameDialog extends StatelessWidget {
  const AuthReservedUsernameDialog({
    super.key,
    required this.requestedUsername,
  });

  final String requestedUsername;

  static Future<bool?> show(
    BuildContext context, {
    required String requestedUsername,
  }) {
    return AuthBrandedDialog.show<bool>(
      context: context,
      barrierDismissible: true,
      title: 'Reserved username',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: Text(
            '$requestedUsername is reserved on Vyooo. To claim it, reach out to our team.\n\n'
            'For now, we will assign you a temporary username. '
            'Our team can update it from the admin dashboard after you contact us.',
            style: AppTypography.authDialogOption,
          ),
        ),
        AuthBrandedDialogActionRow(
          actions: [
            AuthBrandedDialogAction(
              label: 'Choose Another',
              style: AppTypography.authDialogCancel,
              onTap: () => Navigator.of(context).pop(false),
            ),
            AuthBrandedDialogAction(
              label: 'Continue',
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
