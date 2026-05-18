import 'package:flutter/material.dart';

import '../../theme/app_sizes.dart';
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
    return Container(
      height: AppSizes.authToggleHeight,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSizes.authToggleHeight / 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(
          label,
          style: AppTypography.toggleLabel.copyWith(
            color: selected
                ? Colors.black.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ),
    );
  }
}
