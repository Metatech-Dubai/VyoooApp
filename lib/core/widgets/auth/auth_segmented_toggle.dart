import 'package:flutter/material.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Email / phone (or similar) two-option toggle on auth screens.
class AuthSegmentedToggle extends StatelessWidget {
  const AuthSegmentedToggle({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.isLeftSelected,
    required this.onLeftTap,
    required this.onRightTap,
  });

  final String leftLabel;
  final String rightLabel;
  final bool isLeftSelected;
  final VoidCallback onLeftTap;
  final VoidCallback onRightTap;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    return Container(
      height: AppSizes.authToggleHeight,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isLight
            ? AppTheme.lightToggleTrack
            : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSizes.authToggleHeight / 2),
        border: Border.all(
          color: isLight
              ? AppTheme.lightToggleBorder
              : Colors.white.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: leftLabel,
              selected: isLeftSelected,
              onTap: onLeftTap,
            ),
          ),
          Expanded(
            child: _Segment(
              label: rightLabel,
              selected: !isLeftSelected,
              onTap: onRightTap,
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          boxShadow: selected && isLight
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTypography.toggleLabel.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? (isLight
                    ? AppTheme.lightOnSurface
                    : Colors.black.withValues(alpha: 0.9))
                : (isLight
                    ? AppTheme.lightSecondaryText
                    : Colors.white.withValues(alpha: 0.82)),
          ),
        ),
      ),
    );
  }
}
