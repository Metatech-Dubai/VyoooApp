import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Email / phone two-option pill toggle on auth screens (Figma register).
class AuthSegmentedToggle extends StatelessWidget {
  const AuthSegmentedToggle({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.isLeftSelected,
    required this.onLeftTap,
    required this.onRightTap,
    this.leftIcon,
    this.rightIcon,
  });

  final String leftLabel;
  final String rightLabel;
  final bool isLeftSelected;
  final VoidCallback onLeftTap;
  final VoidCallback onRightTap;
  final IconData? leftIcon;
  final IconData? rightIcon;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    final trackRadius = BorderRadius.circular(AppRadius.authToggle);
    final inset = AppSizes.authToggleInset;
    final innerRadius = BorderRadius.circular(AppRadius.authToggle - inset);

    return Container(
      height: AppSizes.authToggleHeight,
      padding: EdgeInsets.all(inset),
      decoration: BoxDecoration(
        color: isLight
            ? AppTheme.lightToggleTrack
            : Colors.white.withValues(alpha: 0.14),
        borderRadius: trackRadius,
        border: isLight
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      foregroundDecoration: isLight
          ? BoxDecoration(
              borderRadius: trackRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.06),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.04),
                ],
                stops: const [0, 0.2, 0.8, 1],
              ),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: leftLabel,
              icon: leftIcon,
              selected: isLeftSelected,
              onTap: onLeftTap,
              borderRadius: innerRadius,
            ),
          ),
          Expanded(
            child: _Segment(
              label: rightLabel,
              icon: rightIcon,
              selected: !isLeftSelected,
              onTap: onRightTap,
              borderRadius: innerRadius,
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.borderRadius,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: borderRadius,
          boxShadow: selected && !isLight
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: AppSizes.fieldIcon - 4,
                color: selected
                    ? (isLight
                        ? AppTheme.lightOnSurface
                        : Colors.black.withValues(alpha: 0.9))
                    : (isLight
                        ? AppTheme.lightToggleUnselected
                        : Colors.white.withValues(alpha: 0.82)),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: AppTypography.toggleLabel.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected
                    ? (isLight
                        ? AppTheme.lightOnSurface
                        : Colors.black.withValues(alpha: 0.9))
                    : (isLight
                        ? AppTheme.lightToggleUnselected
                        : Colors.white.withValues(alpha: 0.82)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
