import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Reusable interest chip for selection. Animates between neutral and selected.
class InterestChip extends StatelessWidget {
  const InterestChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  static const Duration _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _duration,
        curve: Curves.easeInOut,
        height: 36,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.storyItem + 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: AppRadius.pillRadius,
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.black : AppTheme.defaultTextColor,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              isSelected ? Icons.check : Icons.add,
              size: 16,
              color: isSelected ? Colors.black : AppTheme.defaultTextColor,
            ),
          ],
        ),
      ),
    );
  }
}
