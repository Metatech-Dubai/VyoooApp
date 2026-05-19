import 'package:flutter/material.dart';

import '../../theme/app_background_assets.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Shared shell: [Comment_section] background + DM Sans title (iOS & Android).
class AuthBrandedDialog extends StatelessWidget {
  const AuthBrandedDialog({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<Widget> children,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => AuthBrandedDialog(
        title: title,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: ClipRRect(
        borderRadius: AppRadius.pillRadius,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(AppBackgroundAssets.commentsSection),
                fit: BoxFit.cover,
              ),
            ),
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
                  child: Text(title, style: AppTypography.authDialogTitle),
                ),
                ...children,
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Divider + centered label used below dialog actions.
class AuthBrandedDialogActionRow extends StatelessWidget {
  const AuthBrandedDialogActionRow({
    super.key,
    required this.actions,
  });

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: Colors.white.withValues(alpha: 0.12),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions,
          ),
        ),
      ],
    );
  }
}

class AuthBrandedDialogAction extends StatelessWidget {
  const AuthBrandedDialogAction({
    super.key,
    required this.label,
    required this.onTap,
    this.style,
  });

  final String label;
  final VoidCallback onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(
            child: Text(
              label,
              style: style ?? AppTypography.authDialogOption,
            ),
          ),
        ),
      ),
    );
  }
}
