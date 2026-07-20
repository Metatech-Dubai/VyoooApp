import 'package:flutter/material.dart';

import '../../theme/app_light_surface.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_gradient_background.dart';
import 'settings_inner_app_bar.dart';

/// Standard settings sub-page: white background + back title + scroll body.
class SettingsPageShell extends StatelessWidget {
  const SettingsPageShell({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppLightSurface.background,
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsInnerAppBar(title: title),
              if (subtitle != null && subtitle!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    subtitle!,
                    style: AppTypography.caption.copyWith(
                      color: AppLightSurface.secondaryText,
                      height: 1.35,
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsGroupCard extends StatelessWidget {
  const SettingsGroupCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppLightSurface.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppLightSurface.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: AppSpacing.md,
                color: AppLightSurface.divider,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      title: Text(
        title,
        style: AppTypography.authDialogOption.copyWith(
          color: AppLightSurface.primaryText,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: AppTypography.caption.copyWith(
                color: AppLightSurface.secondaryText,
              ),
            ),
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: AppLightSurface.primaryText,
      activeTrackColor: AppLightSurface.primaryText.withValues(alpha: 0.35),
    );
  }
}

class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      title: Text(
        title,
        style: AppTypography.authDialogOption.copyWith(
          color: AppLightSurface.primaryText,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: AppTypography.caption.copyWith(
                color: AppLightSurface.secondaryText,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(
              trailing!,
              style: AppTypography.caption.copyWith(
                color: AppLightSurface.mutedText,
              ),
            ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppLightSurface.chevron,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
