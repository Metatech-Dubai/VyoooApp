import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_version_policy.dart';
import '../navigation/app_keys.dart';
import '../services/app_version_update_service.dart';
import '../theme/app_padding.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'app_gradient_background.dart';
import 'auth/auth_primary_button.dart';
import 'vyooo_brand_logo.dart';
import '../theme/app_light_surface.dart';

/// Full-screen gate when a force update is required.
class AppForceUpdateScreen extends StatelessWidget {
  const AppForceUpdateScreen({
    super.key,
    required this.result,
  });

  final AppUpdateCheckResult result;

  Future<void> _openStore() async {
    final url = result.updateUrl?.trim();
    if (url == null || url.isEmpty) {
      _showLaunchError();
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showLaunchError();
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showLaunchError();
    }
  }

  void _showLaunchError() {
    appScaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Could not open the store. Try again later.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final policy = result.policy ?? AppVersionPolicy.disabled();
    return PopScope(
      canPop: false,
      child: AppGradientBackground(
        child: Padding(
          padding: AppPadding.authFormHorizontal,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const VyoooBrandLogo(),
              AppPadding.sectionGap,
              Text(
                policy.title,
                style: AppTypography.authHeadline.copyWith(
                  color: AppLightSurface.primaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                policy.message,
                style: AppTypography.input.copyWith(
                  color: AppLightSurface.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              if (result.installedVersion != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Installed: ${result.installedVersion}'
                  '${result.targetVersionLabel != null ? ' · Required: ${result.targetVersionLabel}' : ''}',
                  style: AppTypography.caption.copyWith(
                    color: AppLightSurface.mutedText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.authCtaTop),
              AuthPrimaryButton(
                label: policy.updateButtonLabel,
                onPressed: _openStore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showOptionalAppUpdateDialog(
  BuildContext context, {
  required AppUpdateCheckResult result,
}) async {
  final policy = result.policy ?? AppVersionPolicy.disabled();
  final latest = policy.platformPolicy().latestVersion?.trim();
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1A0A24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          policy.title,
          style: AppTypography.label.copyWith(fontSize: 20),
        ),
        content: Text(
          policy.message,
          style: AppTypography.input.copyWith(color: AppTheme.secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (latest != null && latest.isNotEmpty) {
                await AppVersionUpdateService.instance
                    .recordOptionalUpdateDismissed(latest);
              }
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text(
              policy.laterButtonLabel,
              style: AppTypography.authSmallBodyBold,
            ),
          ),
          TextButton(
            onPressed: () async {
              final url = result.updateUrl?.trim();
              if (url != null && url.isNotEmpty) {
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text(
              policy.updateButtonLabel,
              style: AppTypography.authSmallBodyBold.copyWith(
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      );
    },
  );
}
