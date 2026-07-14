import 'package:flutter/material.dart';

import '../../screens/profile/profile_figma_tokens.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Light white/black confirmation sheet for signing out.
abstract final class LogoutConfirmDialog {
  LogoutConfirmDialog._();

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Material(
            color: AppTheme.lightScaffoldBackground,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.md,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Log out',
                        textAlign: TextAlign.center,
                        style: AppTypography.authDialogTitle.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.lightOnSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Do you want to log out of your account?',
                        textAlign: TextAlign.center,
                        style: AppTypography.authDialogOption.copyWith(
                          fontWeight: FontWeight.w400,
                          color: AppTheme.lightSecondaryText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppTheme.lightUnfocusedUnderline,
                ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _LogoutDialogAction(
                          label: 'No, stay',
                          style: AppTypography.authDialogOption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.lightOnSurface,
                          ),
                          onTap: () => Navigator.pop(dialogContext, false),
                        ),
                      ),
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AppTheme.lightUnfocusedUnderline,
                      ),
                      Expanded(
                        child: _LogoutDialogAction(
                          label: 'Yes, log out',
                          style: AppTypography.authDialogOption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: ProfileFigmaTokens.profileMoreDrawerLogoutText,
                          ),
                          onTap: () => Navigator.pop(dialogContext, true),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutDialogAction extends StatelessWidget {
  const _LogoutDialogAction({
    required this.label,
    required this.onTap,
    required this.style,
  });

  final String label;
  final VoidCallback onTap;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(child: Text(label, style: style)),
        ),
      ),
    );
  }
}
