import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'auth_branded_dialog.dart';

/// Account types offered during username onboarding.
enum AuthOnboardingAccountType {
  private,
  public,
  business,
  government,
}

/// Branded account-type picker (iOS & Android).
class AuthAccountTypePickerDialog extends StatelessWidget {
  const AuthAccountTypePickerDialog({super.key});

  static const _options = <(AuthOnboardingAccountType, String)>[
    (AuthOnboardingAccountType.private, 'Private account'),
    (AuthOnboardingAccountType.public, 'Public account'),
    (AuthOnboardingAccountType.business, 'Business account'),
    (AuthOnboardingAccountType.government, 'Government account'),
  ];

  static Future<AuthOnboardingAccountType?> show(BuildContext context) {
    return showDialog<AuthOnboardingAccountType>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const AuthAccountTypePickerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthBrandedDialog(
      title: 'Select account type',
      children: [
        ..._options.map((entry) {
          final (type, label) = entry;
          return _OptionTile(
            label: label,
            onTap: () => Navigator.of(context).pop(type),
          );
        }),
        AuthBrandedDialogActionRow(
          actions: [
            AuthBrandedDialogAction(
              label: 'Cancel',
              style: AppTypography.authDialogCancel,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, style: AppTypography.authDialogOption),
        ),
      ),
    );
  }
}
