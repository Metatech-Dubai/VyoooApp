import 'package:flutter/material.dart';

import '../theme/app_padding.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'vyooo_brand_logo.dart';

/// Common header for feed screens: VyooO logo + tab selector.
/// Selected tab: pill + border (15% fill). Unselected: text only, no background.
/// Typography: unselected DM Sans Regular 14 @ 60% white; selected Bold 16 white.
class AppFeedHeader extends StatelessWidget {
  const AppFeedHeader({
    super.key,
    required this.selectedIndex,
    this.labels = _defaultLabels,
    this.onTabSelected,
    this.trailing,
  });

  final int selectedIndex;
  final List<String> labels;
  final void Function(int index)? onTabSelected;
  final Widget? trailing;

  static const List<String> _defaultLabels = [
    'Trending',
    'VR',
    'Following',
    'For You',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppPadding.screenHorizontal.copyWith(
        top: AppSpacing.sm,
        bottom: AppSpacing.md,
      ),
      child: Row(
        children: [
          _buildLogo(context),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppFeedTabSelector(
              labels: labels,
              selectedIndex: selectedIndex,
              onTabSelected: onTabSelected,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return const VyoooBrandLogo(
      size: AppSizes.feedLogoHeight,
      center: false,
    );
  }
}

/// Tab selector for Trending / VR / Following / For You.
class AppFeedTabSelector extends StatelessWidget {
  const AppFeedTabSelector({
    super.key,
    required this.labels,
    required this.selectedIndex,
    this.onTabSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final void Function(int)? onTabSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (index) {
          final isSelected = selectedIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: GestureDetector(
              onTap: () => onTabSelected?.call(index),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: AppPadding.feedTabChip,
                decoration: isSelected
                    ? BoxDecoration(
                        color: White15.value,
                        borderRadius: AppRadius.pillRadius,
                        border: Border.all(color: AppTheme.primary, width: 1),
                      )
                    : null,
                child: Text(
                  labels[index],
                  style: isSelected
                      ? AppTypography.feedTabLabelSelected
                      : AppTypography.feedTabLabel,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
