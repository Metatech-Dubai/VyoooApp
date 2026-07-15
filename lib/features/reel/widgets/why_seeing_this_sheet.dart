import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_light_surface.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

/// "Why you're seeing this post?" bottom sheet.
void showWhySeeingThisSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _WhySeeingThisSheet(),
  );
}

abstract final class _Layout {
  static const double reasonIconSize = 40;
}

class _WhySeeingThisSheet extends StatelessWidget {
  const _WhySeeingThisSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppBottomSheet.decoration(topRadius: 28),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBottomSheet.dragHandle(),
                Text(
                  "Why you're seeing this post?",
                  style: TextStyle(
                    color: AppLightSurface.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: AppLightSurface.secondaryText,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            'Posts are shown in feed based on many things, including your activity in VyooO. ',
                      ),
                      TextSpan(
                        text: 'Learn More',
                        style: TextStyle(
                          color: AppColors.brandPink,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            // TODO: open learn more URL or in-app page
                          },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _ReasonRow(
                  icon: Icons.person_outline_rounded,
                  label: 'You follow Robert Thank',
                  avatarUrl: 'https://i.pravatar.cc/100?img=12',
                ),
                const SizedBox(height: 24),
                _ReasonRow(
                  icon: Icons.access_time_rounded,
                  label:
                      "You've interacted with content about travel and more.",
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    this.icon,
    this.avatarUrl,
  });

  final String label;
  final IconData? icon;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _Layout.reasonIconSize,
          height: _Layout.reasonIconSize,
          decoration: BoxDecoration(
            color: AppLightSurface.cardFill,
            shape: BoxShape.circle,
            border: Border.all(color: AppLightSurface.border),
          ),
          child: avatarUrl != null
              ? ClipOval(
                  child: Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    width: _Layout.reasonIconSize,
                    height: _Layout.reasonIconSize,
                  ),
                )
              : Icon(
                  icon ?? Icons.autorenew_rounded,
                  size: 22,
                  color: AppLightSurface.icon,
                ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              label,
              style: TextStyle(
                color: AppLightSurface.primaryText,
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
